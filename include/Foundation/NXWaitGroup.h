/**
 * @file NXWaitGroup.h
 * @brief Defines the NXWaitGroup class, for waiting until work in other threads is done.
 */
#pragma once
#include <picofuse/sys.h>

/**
 * @brief A count of work to be done, which threads can wait for to reach zero.
 * @ingroup Foundation
 *
 * Add to it for each piece of work before it starts, and each piece says it's done
 * when it is. It's a picofuse wait group, which are limited in number and shared with
 * the rest of the program. It can't be used in an interrupt.
 *
 * \headerfile NXWaitGroup.h Foundation/Foundation.h
 */
@interface NXWaitGroup : NXObject {
@private
  sys_waitgroup_t *_waitgroup;
}

/**
 * @brief Initializes a wait group, with a count of zero.
 * @return The wait group, or nil if there's no picofuse wait group left or not enough
 * memory.
 */
- (id)init;

/**
 * @brief Adds to the count. Panics if count is negative, or the count would be more
 * than INT_MAX.
 */
- (void)add:(int)count;

/**
 * @brief Takes one away from the count. Panics if it's already zero.
 */
- (void)done;

/**
 * @brief Waits until the count is zero, which is straight away if it already is.
 */
- (void)wait;

@end
