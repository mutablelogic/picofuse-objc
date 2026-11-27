#include <Application/Application.h>
#include <picofuse/sys.h>
#include <runtime/gcc/runtime.h>

static NXApplication *shared = nil;

// Sends an optional message to a delegate, if it has the method
static void tell(id delegate, SEL selector, id argument) {
  if (delegate != nil && class_respondsToSelector(object_getClass(delegate), selector)) {
    void (*imp)(void) = (void (*)(void))objc_msg_lookup(delegate, selector);
    ((void (*)(id, SEL, id))imp)(delegate, selector, argument);
  }
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
    if (_runLoop == nil) {
      [self release];
      return nil;
    }
    [_runLoop setDelegate:self];
  }
  return self;
}

- (void)dealloc {
  [_runLoop release];
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

- (void)runLoopDidStart:(NXRunLoop *)runLoop {
  (void)runLoop;
  tell(_delegate, @selector(applicationDidStart:), self);
}

- (void)runLoopWillStop:(NXRunLoop *)runLoop {
  (void)runLoop;
  tell(_delegate, @selector(applicationWillTerminate:), self);
}

@end
