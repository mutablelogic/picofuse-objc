#include "NXEventSource+Private.h"
#include "NXRunLoop+Private.h"
#include <Application/Application.h>
#include <picofuse/hid.h>
#include <picofuse/sys.h>
#include <runtime/gcc/runtime.h>

static NXApplication *shared = nil;

@interface NXApplication (Private)
- (BOOL)handleHIDEvent:(sys_event_t)event;
- (void)pollHID;
@end

// Sends an optional message to a delegate, if it has the method
static void tell(id delegate, SEL selector, id argument) {
  if (delegate != nil && class_respondsToSelector(object_getClass(delegate), selector)) {
    void (*imp)(void) = (void (*)(void))objc_msg_lookup(delegate, selector);
    ((void (*)(id, SEL, id))imp)(delegate, selector, argument);
  }
}

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
  }
  return self;
}

- (void)dealloc {
  [_runLoop release];
  [_sources release];
  [super dealloc];
}

- (int)run {
  return [_runLoop runWithWorkers:_workers];
}

- (NXRunLoop *)runLoop {
  return _runLoop;
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
  @synchronized(self) {
    _hid = hid_init([runLoop queue]);
    if (_hid == NULL) {
      sys_panicf("-[NXApplication run] HID couldn't be initialized");
    }
    for (id<NXEventSourcePrivate> source in _sources) {
      [source attachToHID:_hid];
    }
  }
  tell(_delegate, @selector(applicationDidStart:), self);
}

// Once every worker has finished, the delegate is told, then every source is detached
// and HID stops
- (void)runLoopWillStop:(NXRunLoop *)runLoop {
  (void)runLoop;
  tell(_delegate, @selector(applicationWillTerminate:), self);
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

- (void)pollHID {
  hid_t *hid = _hid;
  if (hid != NULL) {
    hid_poll(hid);
  }
}

@end
