#include "NXEventSource+Private.h"
#include "NXMethod+Private.h"
#include <Application/Application.h>
#include <picofuse/hid.h>
#include <picofuse/hw.h>
#include <runtime/gcc/runtime.h>

///////////////////////////////////////////////////////////////////////////////
// NXPin

@implementation NXPin

- (uint8_t)bank {
  return _bank;
}

- (uint8_t)pin {
  return _pin;
}

- (BOOL)boolValue {
  return NO;
}

- (NXString *)description {
  return [NXString stringWithFormat:@"<%s %u:%u %s>", object_getClassName(self),
                                    (unsigned)_bank, (unsigned)_pin,
                                    [self boolValue] ? "high" : "low"];
}

@end

///////////////////////////////////////////////////////////////////////////////
// NXDigitalOutput

@implementation NXDigitalOutput

+ (NXDigitalOutput *)outputWithPin:(uint8_t)pin {
  return [self outputWithBank:0 pin:pin];
}

+ (NXDigitalOutput *)outputWithBank:(uint8_t)bank pin:(uint8_t)pin {
  hw_gpio_t *gpio = hw_gpio_init(bank, pin, hw_gpio_output);
  if (gpio == NULL) {
    return nil;
  }
  NXDigitalOutput *output = [[[self alloc] init] autorelease];
  if (output == nil) {
    hw_gpio_deinit(gpio);
    return nil;
  }
  output->_bank = bank;
  output->_pin = pin;
  output->_gpio = gpio;
  hw_gpio_set(gpio, false);
  return output;
}

- (void)dealloc {
  if (_gpio != NULL) {
    hw_gpio_deinit(_gpio);
  }
  [super dealloc];
}

- (BOOL)boolValue {
  return _gpio != NULL && hw_gpio_get(_gpio);
}

- (void)setBoolValue:(BOOL)value {
  if (_gpio != NULL) {
    hw_gpio_set(_gpio, value);
  }
}

- (void)toggle {
  @synchronized(self) {
    [self setBoolValue:![self boolValue]];
  }
}

@end

///////////////////////////////////////////////////////////////////////////////
// NXDigitalInput

@interface NXDigitalInput (Private) <NXEventSourcePrivate>
@end

// Numbers each attachment, which its events carry as their keycode, so those from one
// before can't be taken for this one's
static uint16_t attachments = 0;

@implementation NXDigitalInput

+ (NXDigitalInput *)inputWithPin:(uint8_t)pin
                            pull:(NXPinPull)pull
                          target:(id)target
                        selector:(SEL)selector {
  return [self inputWithBank:0 pin:pin pull:pull target:target selector:selector];
}

+ (NXDigitalInput *)inputWithBank:(uint8_t)bank
                              pin:(uint8_t)pin
                             pull:(NXPinPull)pull
                           target:(id)target
                         selector:(SEL)selector {
  if (target == nil || selector == NULL || NXMethodArguments(selector) != 1 ||
      (pull != NXPinPullNone && pull != NXPinPullUp && pull != NXPinPullDown)) {
    return nil;
  }
  const char *types = object_getMethodTypes(target, selector);
  if (types == NULL || !NXMethodReturnsScalar(types) || !NXMethodTakesObject(types)) {
    return nil;
  }
  NXDigitalInput *input = [[[self alloc] init] autorelease];
  if (input != nil) {
    input->_bank = bank;
    input->_pin = pin;
    input->_pull = pull;
    input->_target = [target retain];
    input->_selector = selector;
  }
  return input;
}

- (void)dealloc {
  [_target release];
  [super dealloc];
}

- (NXPinPull)pull {
  return _pull;
}

- (BOOL)isAttached {
  BOOL attached;
  @synchronized(self) {
    attached = _device != NULL;
  }
  return attached;
}

- (BOOL)boolValue {
  BOOL value = NO;
  @synchronized(self) {
    if (_device != NULL) {
      hw_gpio_t *gpio = hid_device_handle(_device);
      value = gpio != NULL && hw_gpio_get(gpio);
    }
  }
  return value;
}

@end

@implementation NXDigitalInput (Private)

// A HID GPIO device, whose events carry the number of this attachment as their keycode
- (BOOL)attachToHID:(hid_t *)hid {
  BOOL attached = NO;
  @synchronized(self) {
    if (_device == NULL) {
      @synchronized([NXDigitalInput class]) {
        attachments = attachments == UINT16_MAX ? 1 : attachments + 1;
        _attachment = attachments;
      }
      switch (_pull) {
      case NXPinPullUp:
        _device = hid_register_gpio_pullup(hid, _bank, _pin, _attachment, NULL);
        break;
      case NXPinPullDown:
        _device = hid_register_gpio_pulldown(hid, _bank, _pin, _attachment, NULL);
        break;
      default:
        _device = hid_register_gpio_input(hid, _bank, _pin, _attachment, NULL);
        break;
      }
    }
    attached = _device != NULL;
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
    owns = _device != NULL && event->type == hid_event_type_keycode &&
           event->device == _device && event->data.keycode.keycode == _attachment;
  }
  return owns;
}

// Sends the message, while it's still attached
- (void)handleEvent:(hid_event_t *)event {
  (void)event;
  if (![self isAttached]) {
    return;
  }
  [self retain];
  void (*imp)(void) = (void (*)(void))objc_msg_lookup(_target, _selector);
  ((void (*)(id, SEL, id))imp)(_target, _selector, self);
  [self release];
}

@end
