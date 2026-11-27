/**
 * @file NXCondition.h
 * @brief Defines the NXCondition class, for threads which wait for something.
 */
#pragma once
#include "NXDuration.h"
#include "NXLocking.h"
#include <picofuse/sys.h>

/**
 * @brief A lock, and a condition which threads holding it can wait for.
 * @ingroup Foundation
 *
 * A thread locks it, and while what it's waiting for isn't true, waits, which unlocks
 * it until another thread signals it. Waking up doesn't mean it is true, so it's
 * always checked again in a loop:
 *
 * \code
 * [condition lock];
 * while (!ready) {
 *   [condition wait];
 * }
 * [condition unlock];
 * \endcode
 *
 * It's a picofuse condition variable and mutex, which are limited in number and shared
 * with the rest of the program. Its lock isn't recursive, and it can't be used in an
 * interrupt.
 *
 * \headerfile NXCondition.h Foundation/Foundation.h
 */
@interface NXCondition : NXObject <NXLocking> {
@private
  sys_mutex_t *_mutex;
  sys_cond_t *_cond;
}

/**
 * @brief Initializes a condition.
 * @return The condition, or nil if there's no picofuse condition variable or mutex
 * left, or not enough memory.
 */
- (id)init;

/**
 * @brief Locks it, waiting until no other thread holds it. Panics if it can't.
 */
- (void)lock;

/**
 * @brief Unlocks it, which only the thread which locked it can do. Panics if it can't.
 */
- (void)unlock;

/**
 * @brief Unlocks it and waits until it's signalled, then locks it again. It has to be
 * locked by this thread. Panics if it can't wait.
 */
- (void)wait;

/**
 * @brief As wait, but for no longer than a duration.
 * @param duration How long to wait at most, rounded up to a millisecond.
 * @return YES if it was signalled, or NO if the duration passed first, or straight
 * away if it's zero or negative. It's locked again either way.
 */
- (BOOL)waitForDuration:(NXDuration)duration;

/**
 * @brief Wakes one thread which is waiting, if there are any.
 */
- (void)signal;

/**
 * @brief Wakes every thread which is waiting.
 */
- (void)broadcast;

@end
