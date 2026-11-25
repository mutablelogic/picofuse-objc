/**
 * @file NXNumber.h
 * @brief Defines the NXNumber class, for integer, floating point and boolean values.
 */
#pragma once
#include <stdint.h>

/**
 * @brief Returns a random 32-bit signed integer.
 * @ingroup Foundation
 */
int32_t NXRandInt32(void);

/**
 * @brief Returns a random 32-bit unsigned integer.
 * @ingroup Foundation
 */
uint32_t NXRandUnsignedInt32(void);

/**
 * @brief Returns a random 64-bit signed integer.
 * @ingroup Foundation
 */
int64_t NXRandInt64(void);

/**
 * @brief Returns a random 64-bit unsigned integer.
 * @ingroup Foundation
 */
uint64_t NXRandUnsignedInt64(void);

/**
 * @brief An integer, floating point or boolean value, as an object.
 * @ingroup Foundation
 *
 * Numbers can't be changed. They're made in the current autorelease pool, other than
 * zero, true and false: there's only one of each of those, which is never
 * deallocated, and doesn't need a pool. Every number which is made as zero is the same
 * object.
 *
 * A number can be returned as any type, whatever it was made from. As an integer, the
 * fraction of a floating point value is discarded, and it panics if the value is out of
 * range, or isn't a number. As a floating point value, it may be rounded.
 *
 * \headerfile NXNumber.h Foundation/Foundation.h
 */
@interface NXNumber : NXObject

/**
 * @brief Returns a number for a boolean value, which is trueValue or falseValue.
 */
+ (NXNumber *)numberWithBool:(BOOL)value;

/**
 * @brief Returns a number for a 16-bit signed integer.
 * @return The number, which is zeroValue if the value is zero, or nil if the allocation
 * failed.
 */
+ (NXNumber *)numberWithInt16:(int16_t)value;

/**
 * @brief Returns a number for a 16-bit unsigned integer.
 * @return The number, which is zeroValue if the value is zero, or nil if the allocation
 * failed.
 */
+ (NXNumber *)numberWithUnsignedInt16:(uint16_t)value;

/**
 * @brief Returns a number for a 32-bit signed integer.
 * @return The number, which is zeroValue if the value is zero, or nil if the allocation
 * failed.
 */
+ (NXNumber *)numberWithInt32:(int32_t)value;

/**
 * @brief Returns a number for a 32-bit unsigned integer.
 * @return The number, which is zeroValue if the value is zero, or nil if the allocation
 * failed.
 */
+ (NXNumber *)numberWithUnsignedInt32:(uint32_t)value;

/**
 * @brief Returns a number for a 64-bit signed integer.
 * @return The number, which is zeroValue if the value is zero, or nil if the allocation
 * failed.
 */
+ (NXNumber *)numberWithInt64:(int64_t)value;

/**
 * @brief Returns a number for a 64-bit unsigned integer.
 * @return The number, which is zeroValue if the value is zero, or nil if the allocation
 * failed.
 */
+ (NXNumber *)numberWithUnsignedInt64:(uint64_t)value;

/**
 * @brief Returns a number for a 32-bit floating point value.
 * @return The number, which is zeroValue if the value is zero but not negative zero, or
 * nil if the allocation failed.
 */
+ (NXNumber *)numberWithFloat32:(float)value;

/**
 * @brief Returns a number for a 64-bit floating point value.
 * @return The number, which is zeroValue if the value is zero but not negative zero, or
 * nil if the allocation failed.
 */
+ (NXNumber *)numberWithFloat64:(double)value;

/**
 * @brief Returns a number for a random 32-bit signed integer.
 */
+ (NXNumber *)randomInt32;

/**
 * @brief Returns a number for a random 32-bit unsigned integer.
 */
+ (NXNumber *)randomUnsignedInt32;

/**
 * @brief Returns a number for a random 64-bit signed integer.
 */
+ (NXNumber *)randomInt64;

/**
 * @brief Returns a number for a random 64-bit unsigned integer.
 */
+ (NXNumber *)randomUnsignedInt64;

/**
 * @brief Returns the number for true, which is equal to one.
 */
+ (NXNumber *)trueValue;

/**
 * @brief Returns the number for false, which is equal to zero.
 */
+ (NXNumber *)falseValue;

/**
 * @brief Returns the number for zero.
 */
+ (NXNumber *)zeroValue;

/**
 * @brief Returns YES if the value isn't zero. That includes what isn't a number.
 */
- (BOOL)boolValue;

/**
 * @brief Returns the value as a 16-bit signed integer. Panics if it's out of range.
 */
- (int16_t)int16Value;

/**
 * @brief Returns the value as a 16-bit unsigned integer. Panics if it's out of range.
 */
- (uint16_t)unsignedInt16Value;

/**
 * @brief Returns the value as a 32-bit signed integer. Panics if it's out of range.
 */
- (int32_t)int32Value;

/**
 * @brief Returns the value as a 32-bit unsigned integer. Panics if it's out of range.
 */
- (uint32_t)unsignedInt32Value;

/**
 * @brief Returns the value as a 64-bit signed integer. Panics if it's out of range.
 */
- (int64_t)int64Value;

/**
 * @brief Returns the value as a 64-bit unsigned integer. Panics if it's out of range.
 */
- (uint64_t)unsignedInt64Value;

/**
 * @brief Returns the value as a 32-bit floating point value, which is infinite if it's
 * out of range.
 */
- (float)float32Value;

/**
 * @brief Returns the value as a 64-bit floating point value.
 */
- (double)float64Value;

/**
 * @brief Returns YES if the other object is a number with exactly the same value,
 * whatever they were made from.
 *
 * A floating point value which isn't a number is only equal to the same object.
 */
- (BOOL)isEqual:(id)anObject;

@end
