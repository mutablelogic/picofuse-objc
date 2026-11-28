#include "NXMethod+Private.h"
#include "NXRunLoop+Private.h"
#include <Application/Application.h>
#include <picofuse/sys.h>
#include <runtime/gcc/runtime.h>

#define CAPACITY_DEFAULT 32

// clang warns that atomics aren't lock-free on an RP2040, where pico-sdk implements
// them with a spin lock
#if defined(__clang__)
#pragma clang diagnostic ignored "-Watomic-alignment"
#endif

///////////////////////////////////////////////////////////////////////////////
// GLOBALS

// picofuse's run loop is one for the process, and its callbacks have no context, so the
// run loop which runs it is kept here. It's a void pointer, as clang doesn't allow atomic
// operations on an object pointer.
static void *running = NULL;

// Set while the run which is in progress tears down: it's still reserved, so another
// can't start, but it's no longer running, so nothing can be posted to it
static uint32_t stopping = 0;

static NXRunLoop *running_loop(void) {
  if (__atomic_load_n(&stopping, __ATOMIC_ACQUIRE) != 0) {
    return nil;
  }
  return (NXRunLoop *)__atomic_load_n(&running, __ATOMIC_ACQUIRE);
}

// Set once worker 0 has told the delegate the run loop has started: the other workers
// wait for it before they dispatch events
static uint32_t started = 0;

// The running run loop's event handler and poll function, set before it runs
static NXRunLoopEventHandler running_handler = NULL;
static NXRunLoopPoll running_poll = NULL;

static void on_poll(void) {
  if (running_poll != NULL) {
    running_poll();
  }
}

///////////////////////////////////////////////////////////////////////////////
// AN EVENT WHICH SENDS A MESSAGE

@interface NXPerformEvent : NXObject <NXEvent> {
@private
  SEL _selector;
  id _target;
  id _argument;
  BOOL _hasArgument;
}
- (id)initWithSelector:(SEL)selector target:(id)target argument:(id)argument has:(BOOL)has;
@end

static void retain_object(id object) {
  if (object != nil && object_isKindOfClass(object, [NXObject class])) {
    [(NXObject *)object retain];
  }
}

static void release_object(id object) {
  if (object != nil && object_isKindOfClass(object, [NXObject class])) {
    [(NXObject *)object release];
  }
}

@implementation NXPerformEvent

- (id)initWithSelector:(SEL)selector target:(id)target argument:(id)argument has:(BOOL)has {
  self = [super init];
  if (self != nil) {
    _selector = selector;
    _target = target;
    _argument = argument;
    _hasArgument = has;
    retain_object(target);
    retain_object(argument);
  }
  return self;
}

- (void)dealloc {
  release_object(_target);
  release_object(_argument);
  [super dealloc];
}

- (void)dispatch {
  void (*imp)(void) = (void (*)(void))objc_msg_lookup(_target, _selector);
  if (_hasArgument) {
    ((void (*)(id, SEL, id))imp)(_target, _selector, _argument);
  } else {
    ((void (*)(id, SEL))imp)(_target, _selector);
  }
}

@end

///////////////////////////////////////////////////////////////////////////////
// PICOFUSE'S CALLBACKS

// Sends an optional message to a delegate, if it has the method
static void tell(id delegate, SEL selector, id argument) {
  if (delegate != nil && class_respondsToSelector(object_getClass(delegate), selector)) {
    void (*imp)(void) = (void (*)(void))objc_msg_lookup(delegate, selector);
    ((void (*)(id, SEL, id))imp)(delegate, selector, argument);
  }
}

// Worker 0 tells the delegate, and the others wait until it has, as picofuse starts them
// first
static void on_start(uint8_t worker) {
  if (worker == 0) {
    NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
    tell([running_loop() delegate], @selector(runLoopDidStart:), running_loop());
    [pool release];
    __atomic_store_n(&started, 1, __ATOMIC_RELEASE);
    return;
  }
  while (__atomic_load_n(&started, __ATOMIC_ACQUIRE) == 0) {
    sys_sleep_ms(1);
  }
}

// Each event is dispatched in a pool of its own, then released
static void on_event(sys_event_t event) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  if (pool == nil) {
    sys_panicf("-[NXRunLoop runWithWorkers:] out of memory for an autorelease pool");
  }
  if (running_handler != NULL && running_handler(event)) {
    [pool release];
    return;
  }
  [(id<NXEvent>)event dispatch];

  // Released before the pool, as its dealloc, or its target's, may autorelease
  [(NXObject *)event release];
  [pool release];
}

///////////////////////////////////////////////////////////////////////////////
// NXRunLoop

@implementation NXRunLoop

- (id)init {
  return [self initWithCapacity:CAPACITY_DEFAULT];
}

- (id)initWithCapacity:(size_t)capacity {
  self = [super init];
  if (self != nil) {
    _capacity = capacity == 0 ? 1 : capacity;
  }
  return self;
}

+ (NXRunLoop *)runningRunLoop {
  return running_loop();
}

- (id<NXRunLoopDelegate>)delegate {
  return _delegate;
}

- (void)setDelegate:(id<NXRunLoopDelegate>)delegate {
  _delegate = delegate;
}

- (int)runWithWorkers:(uint8_t)workers {
  // Only one at a time, as picofuse's is one for the process. Starting and stopping are
  // under the same lock as posting and shutting down, so those are always for this run.
  BOOL free = NO;
  @synchronized([NXRunLoop class]) {
    free = running == NULL;
    if (free) {
      __atomic_store_n(&running, (void *)self, __ATOMIC_RELEASE);
    }
  }
  if (!free) {
    return -1;
  }
  [self retain];

  // A queue for each run, as it's shut down when the run loop stops
  _queue = sys_event_queue_init(_capacity);
  int status = -1;
  BOOL ran = _queue != NULL;
  if (ran) {
    __atomic_store_n(&started, 0, __ATOMIC_RELEASE);
    running_handler = (NXRunLoopEventHandler)_handler;
    running_poll = (NXRunLoopPoll)_poll;
    status = (int)sys_runloop_run(workers, _queue, on_start, on_event,
                                  _poll != NULL ? on_poll : NULL, NULL);

  }
  // It's stopping: nothing can be posted, but another run can't start until it's torn down
  @synchronized([NXRunLoop class]) {
    __atomic_store_n(&stopping, 1, __ATOMIC_RELEASE);
  }

  // Every worker has finished, so the delegate is told here, while the queue is still
  // there for what it stops, such as HID, which pushes to it
  if (ran) {
    NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
    tell(_delegate, @selector(runLoopWillStop:), self);
    [pool release];
    running_handler = NULL;
    running_poll = NULL;
    sys_event_queue_deinit(_queue);
    _queue = NULL;
  }
  @synchronized([NXRunLoop class]) {
    __atomic_store_n(&running, NULL, __ATOMIC_RELEASE);
    __atomic_store_n(&stopping, 0, __ATOMIC_RELEASE);
  }
  [self release];
  return status;
}

- (BOOL)isRunning {
  return [NXRunLoop runningRunLoop] == self;
}

- (void)shutdownWithStatus:(int)status {
  @synchronized([NXRunLoop class]) {
    if (running_loop() == self) {
      sys_runloop_shutdown((uint32_t)status);
    }
  }
}

- (BOOL)post:(id<NXEvent>)event {
  if (event == nil) {
    return NO;
  }
  BOOL posted = NO;
  [(NXObject *)event retain];
  @synchronized([NXRunLoop class]) {
    posted = running_loop() == self && sys_runloop_post(event);
  }
  if (!posted) {
    [(NXObject *)event release];
  }
  return posted;
}

- (BOOL)perform:(SEL)selector target:(id)target {
  if (target == nil || selector == NULL || NXMethodArguments(selector) != 0) {
    return NO;
  }
  const char *types = object_getMethodTypes(target, selector);
  if (types == NULL || !NXMethodReturnsScalar(types)) {
    return NO;
  }
  NXPerformEvent *event = [[NXPerformEvent alloc] initWithSelector:selector
                                                            target:target
                                                          argument:nil
                                                               has:NO];
  BOOL posted = event != nil && [self post:event];
  [event release];
  return posted;
}

- (BOOL)perform:(SEL)selector target:(id)target argument:(id)argument {
  if (target == nil || selector == NULL || NXMethodArguments(selector) != 1) {
    return NO;
  }
  const char *types = object_getMethodTypes(target, selector);
  if (types == NULL || !NXMethodReturnsScalar(types) || !NXMethodTakesObject(types)) {
    return NO;
  }
  NXPerformEvent *event = [[NXPerformEvent alloc] initWithSelector:selector
                                                            target:target
                                                          argument:argument
                                                               has:YES];
  BOOL posted = event != nil && [self post:event];
  [event release];
  return posted;
}

@end

@implementation NXRunLoop (Private)

- (sys_event_queue_t *)queue {
  return _queue;
}

- (void)setEventHandler:(NXRunLoopEventHandler)handler poll:(NXRunLoopPoll)poll {
  _handler = (void *)handler;
  _poll = (void *)poll;
}

@end
