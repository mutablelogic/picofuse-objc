/**
 * @file NXTimer.h
 * @brief Defines the NXTimer class, which sends a message after an interval.
 */
#pragma once
#include "NXEventSource.h"
#include <Foundation/Foundation.h>

/**
 * @brief Sends a message to a target after an interval, once or repeatedly, on the
 * application's run loop.
 * @ingroup Application
 *
 * It's a timer of picofuse's HID, which there's a limited number of. Once scheduled, it
 * stays attached to the application, and retained by it, until it's invalidated, or has
 * fired once if it doesn't repeat. The message is sent on any of the run loop's workers,
 * so if the run loop is busy, firings of a repeating timer can be sent at the same time
 * on different workers.
 *
 * \headerfile NXTimer.h Application/Application.h
 */
@interface NXTimer : NXObject <NXEventSource> {
@private
  NXDuration _interval; ///< How long between firings
  BOOL _repeats;        ///< YES to fire until invalidated
  id _target;           ///< Retained
  SEL _selector;        ///< Has the timer as its argument
  void *_device;        ///< The HID device while it's attached, or NULL
  BOOL _valid;          ///< NO once it's been invalidated
}

/**
 * @brief Returns a new timer, which isn't scheduled.
 * @param interval How long before it fires, and between firings, rounded up to a
 * millisecond.
 * @param repeats YES to fire until it's invalidated, or NO to fire once.
 * @param target What the message is sent to, which is retained.
 * @param selector A method of the target which has the timer as its one argument, such as
 * -tick:(NXTimer *)timer.
 * @return The timer, or nil if the interval isn't more than zero, the target doesn't have
 * the method, or there isn't enough memory.
 */
+ (NXTimer *)timerWithInterval:(NXDuration)interval
                       repeats:(BOOL)repeats
                        target:(id)target
                      selector:(SEL)selector;

/**
 * @brief Schedules it, by attaching it to the shared application: it starts when the
 * application runs, or straight away if it's running.
 * @return YES, or NO if it's been invalidated, or there's no HID timer left.
 */
- (BOOL)schedule;

/**
 * @brief Stops it, and detaches it from the application. It doesn't fire after this, and
 * can't be scheduled again.
 */
- (void)invalidate;

/**
 * @brief Sends the message now, on the calling thread, whether or not it's scheduled.
 */
- (void)fire;

/**
 * @brief Returns the interval.
 */
- (NXDuration)interval;

/**
 * @brief Returns YES if it repeats.
 */
- (BOOL)repeats;

/**
 * @brief Returns YES until it's been invalidated, or has fired once if it doesn't repeat.
 */
- (BOOL)isValid;

@end
