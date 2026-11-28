/**
 * @file NXPin.h
 * @brief Defines NXPin, and the digital inputs and outputs which are pins.
 */
#pragma once
#include "NXEventSource.h"
#include <Foundation/Foundation.h>

/**
 * @brief Whether an input is pulled up or down when nothing drives it.
 * @ingroup Application
 */
typedef enum {
  NXPinPullNone = 0, ///< Neither, so it floats when nothing drives it
  NXPinPullUp,       ///< Pulled up, so it's high when nothing drives it
  NXPinPullDown,     ///< Pulled down, so it's low when nothing drives it
} NXPinPull;

/**
 * @brief A pin of picofuse's GPIO: one of a bank's pins, and its level.
 * @ingroup Application
 *
 * Pins need picofuse's hardware to have started, which NXApplicationMain does before it
 * makes the delegate, or hw_init() does.
 *
 * \headerfile NXPin.h Application/Application.h
 */
@interface NXPin : NXObject {
@protected
  uint8_t _bank; ///< The bank, which is 0 on a Pico
  uint8_t _pin;  ///< The pin in the bank
}

/**
 * @brief Returns the bank, which is 0 on a Pico.
 */
- (uint8_t)bank;

/**
 * @brief Returns the pin in the bank.
 */
- (uint8_t)pin;

/**
 * @brief Returns YES if the pin is high, or NO if it's low or can't be read.
 */
- (BOOL)boolValue;

@end

/**
 * @brief A pin which is driven high or low.
 * @ingroup Application
 *
 * It's the pin's from when it's made until it's deallocated.
 *
 * \headerfile NXPin.h Application/Application.h
 */
@interface NXDigitalOutput : NXPin {
@private
  void *_gpio; ///< picofuse's GPIO
}

/**
 * @brief Returns an output on a pin of bank 0, which is driven low.
 * @return The output, or nil if the pin can't be an output, such as when there's no
 * GPIO, as on a Mac.
 */
+ (NXDigitalOutput *)outputWithPin:(uint8_t)pin;

/**
 * @brief Returns an output on a pin of a bank, which is driven low.
 * @return The output, or nil if the pin can't be an output.
 */
+ (NXDigitalOutput *)outputWithBank:(uint8_t)bank pin:(uint8_t)pin;

/**
 * @brief Drives the pin high, or low.
 */
- (void)setBoolValue:(BOOL)value;

/**
 * @brief Drives the pin to the other level.
 */
- (void)toggle;

@end

/**
 * @brief A pin which is read, and which sends a message to a target when its level
 * changes, as an event source of the application.
 * @ingroup Application
 *
 * It's a GPIO device of picofuse's HID, which debounces it, while it's attached with
 * -[NXApplication attachEventSource:], and it can only be read then. The message is sent
 * on any of the run loop's workers, with the input as its argument.
 *
 * \headerfile NXPin.h Application/Application.h
 */
@interface NXDigitalInput : NXPin <NXEventSource> {
@private
  NXPinPull _pull;       ///< Up, down or neither
  id _target;            ///< Retained
  SEL _selector;         ///< Has the input as its argument
  void *_device;         ///< The HID device while it's attached, or NULL
  uint16_t _attachment;  ///< Which attachment it's in, which its HID events carry
}

/**
 * @brief Returns an input on a pin of bank 0, which isn't attached.
 * @param pin The pin in the bank.
 * @param pull Whether it's pulled up, down, or neither.
 * @param target What the message is sent to when its level changes, which is retained.
 * @param selector A method of the target which has the input as its one argument, such
 * as -pinDidChange:.
 * @return The input, or nil if the selector isn't a method of the target which takes
 * one object.
 */
+ (NXDigitalInput *)inputWithPin:(uint8_t)pin
                            pull:(NXPinPull)pull
                          target:(id)target
                        selector:(SEL)selector;

/**
 * @brief Returns an input on a pin of a bank, which isn't attached.
 */
+ (NXDigitalInput *)inputWithBank:(uint8_t)bank
                              pin:(uint8_t)pin
                             pull:(NXPinPull)pull
                           target:(id)target
                         selector:(SEL)selector;

/**
 * @brief Returns whether it's pulled up, down, or neither.
 */
- (NXPinPull)pull;

/**
 * @brief Returns YES if it's attached, so it can be read and sends its message.
 */
- (BOOL)isAttached;

@end
