/**
 * @file NXAnalogInput.h
 * @brief Defines NXAnalogInput, which reads an ADC channel or the temperature sensor.
 */
#pragma once
#include "NXEventSource.h"
#include <Foundation/Foundation.h>

/**
 * @brief An ADC channel, or the internal temperature sensor, which is read at an
 * interval, and which sends a message to a target when its reading changes, as an
 * event source of the application.
 * @ingroup Application
 *
 * It's an ADC device of picofuse's HID while it's attached with
 * -[NXApplication attachEventSource:], and it can only be read then. The message is sent
 * on any of the run loop's workers, with the input as its argument. Where there's no
 * ADC, as on a Mac or Linux, it doesn't attach. On an RP2040, channels 0 to 2 are GP26
 * to GP28, and 3 is GP29, which on a Pico W is a third of VSYS.
 *
 * \headerfile NXAnalogInput.h Application/Application.h
 */
@interface NXAnalogInput : NXObject <NXEventSource> {
@private
  uint8_t _channel;         ///< The ADC channel, which isn't the temperature sensor's
  BOOL _temperature;        ///< YES for the temperature sensor
  NXDuration _interval;     ///< How often it's read
  id _target;               ///< Retained
  SEL _selector;            ///< Has the input as its argument
  void *_device;            ///< The HID device while it's attached, or NULL
}

/**
 * @brief Returns an input on an ADC channel, which isn't attached.
 * @param channel The ADC channel.
 * @param interval How often it's read, rounded up to a millisecond.
 * @param target What the message is sent to when its reading changes, which is
 * retained.
 * @param selector A method of the target which has the input as its one argument.
 * @return The input, or nil if the interval isn't positive, or the selector isn't a
 * method of the target which takes one object.
 */
+ (NXAnalogInput *)inputWithChannel:(uint8_t)channel
                           interval:(NXDuration)interval
                             target:(id)target
                           selector:(SEL)selector;

/**
 * @brief Returns an input on the internal temperature sensor, which isn't attached.
 * @return The input, or nil, as for inputWithChannel:interval:target:selector:.
 */
+ (NXAnalogInput *)temperatureWithInterval:(NXDuration)interval
                                    target:(id)target
                                  selector:(SEL)selector;

/**
 * @brief Returns the ADC channel, which is 0 for the temperature sensor.
 */
- (uint8_t)channel;

/**
 * @brief Returns YES if it's the internal temperature sensor.
 */
- (BOOL)isTemperature;

/**
 * @brief Returns how often it's read.
 */
- (NXDuration)interval;

/**
 * @brief Returns YES if it's attached, so it can be read and sends its message.
 */
- (BOOL)isAttached;

/**
 * @brief Reads it now: volts for an ADC channel, or degrees Celsius for the temperature
 * sensor, or 0 if it isn't attached.
 */
- (float)floatValue;

@end
