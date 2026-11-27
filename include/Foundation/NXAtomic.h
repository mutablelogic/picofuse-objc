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
 * It's a picofuse atomic. Each change is whole, so it's right for counts and flags, but
 * it doesn't order what else a thread reads and writes: it can't be used to say that
 * other data is ready for another thread, for which there's NXCondition. It can't be
 * used in an interrupt, as sending a message there isn't safe.
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
