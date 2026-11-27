#include "NXEventSource+Private.h"
#include "NXMethod+Private.h"
#include <Application/Application.h>
#include <picofuse/hid.h>
#include <runtime/gcc/runtime.h>

@interface NXTimer (Private) <NXEventSourcePrivate>
@end

@implementation NXTimer

+ (NXTimer *)timerWithInterval:(NXDuration)interval
                       repeats:(BOOL)repeats
                        target:(id)target
                      selector:(SEL)selector {
  if (interval <= 0 || target == nil || selector == NULL || NXMethodArguments(selector) != 1) {
    return nil;
  }
  const char *types = object_getMethodTypes(target, selector);
  if (types == NULL || !NXMethodReturnsScalar(types) || !NXMethodTakesObject(types)) {
    return nil;
  }
  NXTimer *timer = [[[self alloc] init] autorelease];
  if (timer != nil) {
    timer->_interval = interval;
    timer->_repeats = repeats;
    timer->_target = [target retain];
    timer->_selector = selector;
    timer->_valid = YES;
  }
  return timer;
}

- (void)dealloc {
  [_target release];
  [super dealloc];
}

- (BOOL)schedule {
  return _valid && [[NXApplication sharedApplication] attachEventSource:self];
}

- (void)invalidate {
  _valid = NO;
  [[NXApplication sharedApplication] detachEventSource:self];
}

- (void)fire {
  void (*imp)(void) = (void (*)(void))objc_msg_lookup(_target, _selector);
  ((void (*)(id, SEL, id))imp)(_target, _selector, self);
}

- (NXDuration)interval {
  return _interval;
}

- (BOOL)repeats {
  return _repeats;
}

- (BOOL)isValid {
  return _valid;
}

@end

@implementation NXTimer (Private)

// A HID timer, whose events have this timer as their userdata
- (BOOL)attachToHID:(hid_t *)hid {
  if (!_valid || _device != NULL) {
    return NO;
  }
  NXDuration ms = (_interval - 1) / NXMillisecond + 1;
  _device = hid_register_timer(hid, 0, ms > UINT32_MAX ? UINT32_MAX : (uint32_t)ms, _repeats,
                               self);
  return _device != NULL;
}

- (void)detachFromHID:(hid_t *)hid {
  if (_device != NULL) {
    hid_deregister(hid, _device);
    _device = NULL;
  }
}

- (BOOL)ownsEvent:(hid_event_t *)event {
  return _device != NULL && event->type == hid_event_type_timer &&
         event->device == _device && event->data.timer.userdata == self;
}

// Sends the message, and if it doesn't repeat, it's done: HID deregisters its device when
// the event is freed, so it's forgotten rather than deregistered again
- (void)handleEvent:(hid_event_t *)event {
  (void)event;
  [self retain];
  [self fire];
  if (!_repeats) {
    _valid = NO;
    _device = NULL;
    [[NXApplication sharedApplication] detachEventSource:self];
  }
  [self release];
}

@end
