/**
 * @file NXAtomic.h
 * @brief Defines the NXAtomic class, for a number which threads change together.
 */
#pragma once
#include <picofuse/sys.h>
#include <stdint.h>

/**
 * @brief A 32-bit unsigned number, which threads can read and change without a lock.
 * @ingroup Foundation
 *
 * It's a picofuse atomic. Each change is whole. A value set with setUnsignedInt32Value:
 * or compareAndSwap:with: hands over what the thread wrote before it to a thread which
 * then reads the value, so it can say that other data is ready. increment, decrement
 * and the bits don't: they're for counts and flags. It can't be used in an interrupt,
 * as sending a message there isn't safe.
 *
 * \headerfile NXAtomic.h Foundation/Foundation.h
 */
@interface NXAtomic : NXObject {
@private
  sys_atomic_t _atomic;
}

/**
 * @brief Returns a new atomic.
 */
+ (id)atomicWithUnsignedInt32:(uint32_t)value;

/**
 * @brief Initializes an atomic with a value.
 */
- (id)initWithUnsignedInt32:(uint32_t)value;

/**
 * @brief Returns the value.
 */
- (uint32_t)unsignedInt32Value;

/**
 * @brief Sets the value.
 */
- (void)setUnsignedInt32Value:(uint32_t)value;

/**
 * @brief Sets the value, if it's what's expected.
 * @param expected The value it has to be.
 * @param desired The value to set.
 * @return YES if it was expected and is now desired, or NO if another thread changed it
 * first, when it's left as it is.
 */
- (BOOL)compareAndSwap:(uint32_t)expected with:(uint32_t)desired;

/**
 * @brief Adds one, wrapping around to zero, and returns the new value.
 */
- (uint32_t)increment;

/**
 * @brief Takes away one, wrapping around to UINT32_MAX, and returns the new value.
 */
- (uint32_t)decrement;

/**
 * @brief Sets the bits which are set in a mask.
 */
- (void)setBits:(uint32_t)mask;

/**
 * @brief Clears the bits which are set in a mask.
 */
- (void)clearBits:(uint32_t)mask;

/**
 * @brief Returns the value, in decimal.
 */
- (NXString *)description;

@end
