/**
 * @file NXLock.h
 * @brief Defines the NXLock class, for mutual exclusion between threads.
 */
#pragma once
#include "NXLocking.h"
#include <picofuse/sys.h>

/**
 * @brief A lock, which one thread at a time can hold.
 * @ingroup Foundation
 *
 * It's a picofuse mutex. They're limited in number, shared with the rest of the
 * program, so a lock is best shared, not made for each object. It isn't recursive:
 * a thread which locks it again while it holds it waits for ever. \@synchronized is
 * recursive. It can't be used in an interrupt.
 *
 * \headerfile NXLock.h Foundation/Foundation.h
 */
@interface NXLock : NXObject <NXLocking> {
@private
  sys_mutex_t *_mutex;
}

/**
 * @brief Initializes a lock.
 * @return The lock, or nil if there's no picofuse mutex left or not enough memory.
 */
- (id)init;

/**
 * @brief Locks it, waiting until no other thread holds it. Panics if it can't.
 */
- (void)lock;

/**
 * @brief Locks it if no thread holds it.
 * @return YES if it's now locked by this thread, or NO if another thread holds it.
 */
- (BOOL)tryLock;

/**
 * @brief Unlocks it, which only the thread which locked it can do. Panics if it can't.
 */
- (void)unlock;

@end
