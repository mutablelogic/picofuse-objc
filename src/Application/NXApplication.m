#include "NXApplication+Private.h"
#include "NXEventSource+Private.h"
#include "NXRunLoop+Private.h"
#include <Application/Application.h>
#include <picofuse/hid.h>
#include <picofuse/hw.h>
#include <picofuse/sys.h>
#include <runtime/gcc/runtime.h>

static NXApplication *shared = nil;

@interface NXApplication (Private)
- (BOOL)handleHIDEvent:(sys_event_t)event;
- (void)pollHID;
@end

// The run loop's event handler and poll function, for HID
static BOOL handle_event(sys_event_t event) {
  return [shared handleHIDEvent:event];
}

static void poll_hid(void) {
  [shared pollHID];
}

// Returns the index of an object in an array, by identity, or NXNotFound
static size_t index_of(NXArray *array, id object) {
  for (size_t i = 0; i < [array count]; i++) {
    if ([array objectAtIndex:i] == object) {
      return i;
    }
  }
  return NXNotFound;
}

@implementation NXApplication

+ (NXApplication *)sharedApplication {
  @synchronized([NXApplication class]) {
    if (shared == nil) {
      shared = [[NXApplication alloc] init];
      if (shared == nil) {
        sys_panicf("+[NXApplication sharedApplication] out of memory");
      }
    }
  }
  return shared;
}

+ (int)run {
  return [[self sharedApplication] run];
}

- (id)init {
  self = [super init];
  if (self != nil) {
    _runLoop = [[NXRunLoop alloc] init];
    _sources = [[NXArray alloc] init];
    if (_runLoop == nil || _sources == nil) {
      [self release];
      return nil;
    }
    [_runLoop setDelegate:self];
    [_runLoop setEventHandler:handle_event poll:poll_hid];
    _workers = 1;
  }
  return self;
}

- (void)dealloc {
  [_runLoop release];
  [_sources release];
  [_environment release];
  [_flags release];
  [super dealloc];
}

- (int)run {
  _signal = 0;
  return [_runLoop runWithWorkers:_workers];
}

- (NXRunLoop *)runLoop {
  return _runLoop;
}

- (NXEnvironment *)environment {
  return _environment;
}

- (NXMap *)flags {
  return _flags;
}

- (uint8_t)workers {
  return _workers;
}

- (void)setWorkers:(uint8_t)workers {
  _workers = workers;
}

- (id<NXApplicationDelegate>)delegate {
  return _delegate;
}

- (void)setDelegate:(id<NXApplicationDelegate>)delegate {
  _delegate = delegate;
}

- (void)terminateWithStatus:(int)status {
  [_runLoop shutdownWithStatus:status];
}

- (BOOL)attachEventSource:(id<NXEventSource>)source {
  if (source == nil ||
      !class_conformsTo(object_getClass(source),
                        (objc_protocol_t *)@protocol(NXEventSourcePrivate))) {
    return NO;
  }
  BOOL attached = NO;
  @synchronized(self) {
    if (index_of(_sources, source) == NXNotFound &&
        (_hid == NULL || [(id<NXEventSourcePrivate>)source attachToHID:_hid])) {
      attached = [_sources appendObject:source];
      if (!attached && _hid != NULL) {
        [(id<NXEventSourcePrivate>)source detachFromHID:_hid];
      }
    }
  }
  return attached;
}

- (void)detachEventSource:(id<NXEventSource>)source {
  id detached = nil;
  @synchronized(self) {
    size_t index = index_of(_sources, source);
    if (index != NXNotFound) {
      detached = [[_sources objectAtIndex:index] retain];
      if (_hid != NULL) {
        [(id<NXEventSourcePrivate>)source detachFromHID:_hid];
      }
      [_sources removeObjectAtIndex:index];
    }
  }
  [detached release];
}

// HID starts on the run loop's queue, with every source attached, before any event is
// dispatched
- (void)runLoopDidStart:(NXRunLoop *)runLoop {
  // Sources which can't start, such as when there's no HID timer left, are detached
  NXArray *failed = [NXArray array];
  @synchronized(self) {
    _hid = hid_init([runLoop queue]);
    if (_hid == NULL) {
      sys_panicf("-[NXApplication run] HID couldn't be initialized");
    }
    // In the order they were attached, so the first get what HID has
    size_t i = 0;
    while (i < [_sources count]) {
      id<NXEventSourcePrivate> source = [_sources objectAtIndex:i];
      if ([source attachToHID:_hid]) {
        i++;
      } else {
        [failed appendObject:source];
        [_sources removeObjectAtIndex:i];
      }
    }
  }
  (void)failed; // released with the pool, outside the lock
  SEL selector = @selector(applicationDidStart:watchdogReset:);
  if (_delegate != nil && class_respondsToSelector(object_getClass(_delegate), selector)) {
    void (*imp)(void) = (void (*)(void))objc_msg_lookup(_delegate, selector);
    ((void (*)(id, SEL, id, BOOL))imp)(_delegate, selector, self, _watchdogReset);
  }
}

// Once every worker has finished, the delegate is told, then every source is detached
// and HID stops
- (void)runLoopWillStop:(NXRunLoop *)runLoop {
  (void)runLoop;
  SEL selector = @selector(applicationWillTerminate:signal:);
  if (_delegate != nil && class_respondsToSelector(object_getClass(_delegate), selector)) {
    void (*imp)(void) = (void (*)(void))objc_msg_lookup(_delegate, selector);
    ((void (*)(id, SEL, id, int))imp)(_delegate, selector, self, _signal);
  }
  @synchronized(self) {
    for (id<NXEventSourcePrivate> source in _sources) {
      [source detachFromHID:_hid];
    }
    hid_deinit(_hid);
    _hid = NULL;
  }
}

@end

@implementation NXApplication (Private)

// A HID event goes to the source it's from, if it's still attached, and is then freed
- (BOOL)handleHIDEvent:(sys_event_t)event {
  hid_t *hid = _hid;
  if (hid == NULL || !hid_event_owned(hid, event)) {
    return NO;
  }
  id<NXEventSourcePrivate> source = nil;
  @synchronized(self) {
    for (id<NXEventSourcePrivate> s in _sources) {
      if ([s ownsEvent:event]) {
        source = (id<NXEventSourcePrivate>)[(NXObject *)s retain];
        break;
      }
    }
  }
  [source handleEvent:event];
  [(NXObject *)source release];
  hid_event_free(event);
  return YES;
}

// On worker 0, about every 50 ms: HID, and the hardware, which feeds the watchdog
- (void)pollHID {
  hid_t *hid = _hid;
  if (hid != NULL) {
    hid_poll(hid);
  }
  if (_hardware) {
    hw_poll();
  }
}

@end

@implementation NXApplication (Main)

- (void)setEnvironment:(NXEnvironment *)environment flags:(NXMap *)flags {
  [_environment release];
  [_flags release];
  _environment = [environment retain];
  _flags = [flags retain];
}

- (void)setHardware:(BOOL)hardware {
  _hardware = hardware;
}

- (void)setWatchdogReset:(BOOL)reset {
  _watchdogReset = reset;
}

- (void)terminateWithSignal:(int)signal {
  _signal = signal;
  [self terminateWithStatus:128 + signal];
}

@end
