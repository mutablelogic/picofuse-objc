#include "NXEventSource+Private.h"
#include "NXMethod+Private.h"
#include <Application/Application.h>
#include <picofuse/hid.h>
#include <picofuse/hw.h>
#include <runtime/gcc/runtime.h>

// Conversions averaged for each reading
#define SAMPLES 8

// Numbers each attachment, which its events carry as the device's userdata, so those
// from one before, or from another input which had the same HID device, are ignored
static uintptr_t attachments = 0;

@interface NXAnalogInput (Private) <NXEventSourcePrivate>
+ (NXAnalogInput *)inputWithChannel:(uint8_t)channel
                        temperature:(BOOL)temperature
                           interval:(NXDuration)interval
                             target:(id)target
                           selector:(SEL)selector;
@end

@implementation NXAnalogInput

+ (NXAnalogInput *)inputWithChannel:(uint8_t)channel
                           interval:(NXDuration)interval
                             target:(id)target
                           selector:(SEL)selector {
  return [self inputWithChannel:channel
                    temperature:NO
                       interval:interval
                         target:target
                       selector:selector];
}

+ (NXAnalogInput *)temperatureWithInterval:(NXDuration)interval
                                    target:(id)target
                                  selector:(SEL)selector {
  return [self inputWithChannel:0
                    temperature:YES
                       interval:interval
                         target:target
                       selector:selector];
}

- (void)dealloc {
  [_target release];
  [super dealloc];
}

- (uint8_t)channel {
  return _channel;
}

- (BOOL)isTemperature {
  return _temperature;
}

- (NXDuration)interval {
  return _interval;
}

- (BOOL)isAttached {
  BOOL attached;
  @synchronized(self) {
    attached = _device != NULL;
  }
  return attached;
}

- (float)floatValue {
  float value = 0;
  @synchronized(self) {
    hw_adc_t *adc = _device != NULL ? hid_device_handle(_device) : NULL;
    if (adc != NULL) {
      value = _temperature ? hw_adc_read_temperature(adc, SAMPLES)
                           : hw_adc_read_voltage(adc, SAMPLES);
    }
  }
  return value;
}

- (NXString *)description {
  return _temperature
             ? [NXString stringWithFormat:@"<%s temperature>", object_getClassName(self)]
             : [NXString stringWithFormat:@"<%s channel %u>", object_getClassName(self),
                                          (unsigned)_channel];
}

@end

@implementation NXAnalogInput (Private)

+ (NXAnalogInput *)inputWithChannel:(uint8_t)channel
                        temperature:(BOOL)temperature
                           interval:(NXDuration)interval
                             target:(id)target
                           selector:(SEL)selector {
  if (interval <= 0 || target == nil || selector == NULL || NXMethodArguments(selector) != 1) {
    return nil;
  }
  const char *types = object_getMethodTypes(target, selector);
  if (types == NULL || !NXMethodReturnsScalar(types) || !NXMethodTakesObject(types)) {
    return nil;
  }
  NXAnalogInput *input = [[[self alloc] init] autorelease];
  if (input != nil) {
    input->_channel = channel;
    input->_temperature = temperature;
    input->_interval = interval;
    input->_target = [target retain];
    input->_selector = selector;
  }
  return input;
}

// A HID ADC device, polled at the interval, which posts an event when its reading
// changes
- (BOOL)attachToHID:(hid_t *)hid {
  BOOL attached = NO;
  @synchronized(self) {
    if (_device == NULL) {
      NXDuration ms = (_interval - 1) / NXMillisecond + 1;
      uint32_t interval = ms > UINT32_MAX ? UINT32_MAX : (uint32_t)ms;
      @synchronized([NXAnalogInput class]) {
        _attachment = ++attachments;
      }
      void *userdata = (void *)_attachment;
      _device = _temperature
                    ? hid_register_temperature(hid, interval, userdata)
                    : hid_register_adc(hid, _channel, NULL, SAMPLES, interval, userdata);
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
    owns = _device != NULL && event->type == hid_event_type_metric &&
           event->device == _device && event->data.metric.userdata == (void *)_attachment;
  }
  return owns;
}

// Sends the message, if the event is still this attachment's: it may have been
// detached and attached again since the application found it was. The reading is
// -floatValue, which is read when it's asked for.
- (void)handleEvent:(hid_event_t *)event {
  if (![self ownsEvent:event]) {
    return;
  }
  [self retain];
  void (*imp)(void) = (void (*)(void))objc_msg_lookup(_target, _selector);
  ((void (*)(id, SEL, id))imp)(_target, _selector, self);
  [self release];
}

@end
