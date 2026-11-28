#include "NXEventSource+Private.h"
#include "NXMethod+Private.h"
#include <Application/Application.h>
#include <picofuse/hid.h>
#include <runtime/gcc/runtime.h>

// clang warns that atomics aren't lock-free on an RP2040, where pico-sdk implements
// them with a spin lock
#if defined(__clang__)
#pragma clang diagnostic ignored "-Watomic-alignment"
#endif

@interface NXTimer (Private) <NXEventSourcePrivate>
- (void)send;
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
  return [self isValid] && [[NXApplication sharedApplication] attachEventSource:self];
}

- (void)invalidate {
  @synchronized(self) {
    _valid = NO;
  }
  [[NXApplication sharedApplication] detachEventSource:self];
}

- (void)fire {
  if ([self isValid]) {
    [self send];
  }
}

- (NXDuration)interval {
  return _interval;
}

- (BOOL)repeats {
  return _repeats;
}

- (BOOL)isValid {
  BOOL valid;
  @synchronized(self) {
    valid = _valid;
  }
  return valid;
}

@end

// Numbers each attachment, so ticks from one before can't be taken for this one's
static uintptr_t attachments = 0;

@implementation NXTimer (Private)

- (void)send {
  void (*imp)(void) = (void (*)(void))objc_msg_lookup(_target, _selector);
  ((void (*)(id, SEL, id))imp)(_target, _selector, self);
}

// A HID timer which always repeats, as a one-shot HID timer can only be released by
// freeing its event: a one-shot timer is deregistered once it's fired instead. Its events
// carry the number of this attachment. If there's no HID timer left, it's invalidated.
- (BOOL)attachToHID:(hid_t *)hid {
  BOOL attached = NO;
  @synchronized(self) {
    if (_valid && _device == NULL) {
      _attachment = __atomic_add_fetch(&attachments, 1, __ATOMIC_RELAXED);
      NXDuration ms = (_interval - 1) / NXMillisecond + 1;
      _device = hid_register_timer(hid, 0, ms > UINT32_MAX ? UINT32_MAX : (uint32_t)ms, true,
                                   (void *)_attachment);
      attached = _device != NULL;
      if (!attached) {
        _valid = NO;
      }
    }
  }
  return attached;
}

- (void)detachFromHID:(hid_t *)hid {
  @synchronized(self) {
    if (_device != NULL) {
      hid_deregister(hid, _device);
      _device = NULL;
    }
  }
}

- (BOOL)ownsEvent:(hid_event_t *)event {
  BOOL owns;
  @synchronized(self) {
    owns = _device != NULL && event->type == hid_event_type_timer &&
           event->device == _device && event->data.timer.userdata == (void *)_attachment;
  }
  return owns;
}

// Sends the message if it's still valid. If it doesn't repeat, it's done, and detached.
- (void)handleEvent:(hid_event_t *)event {
  (void)event;
  BOOL send = NO, done = NO;
  @synchronized(self) {
    send = _valid;
    if (_valid && !_repeats) {
      _valid = NO;
      done = YES;
    }
  }
  [self retain];
  if (send) {
    [self send];
  }
  if (done) {
    [[NXApplication sharedApplication] detachEventSource:self];
  }
  [self release];
}

@end
