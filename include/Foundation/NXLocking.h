/**
 * @file NXLocking.h
 * @brief Defines the NXLocking protocol, for objects which can be locked.
 */
#pragma once

/**
 * @brief Objects which can be locked by one thread at a time.
 * @ingroup Foundation
 *
 * \headerfile NXLocking.h Foundation/Foundation.h
 */
@protocol NXLocking

/**
 * @brief Locks it, waiting until no other thread holds it.
 */
- (void)lock;

/**
 * @brief Unlocks it, which only the thread which locked it can do.
 */
- (void)unlock;

@end
