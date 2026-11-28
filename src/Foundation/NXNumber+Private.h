#pragma once
#include <Foundation/Foundation.h>

/*
 * What each kind of number implements. NXNumber itself does everything else.
 */
@interface NXNumber (Private)

/*
 * Returns the magnitude of the value as an integer, and YES if it's negative. It
 * isn't negative if the magnitude is zero.
 */
- (BOOL)isNegative:(uint64_t *)magnitude;

/*
 * Returns YES if it's a floating point number
 */
- (BOOL)isFloat;

/*
 * Returns YES if it's an unsigned integer
 */
- (BOOL)isUnsigned;

@end

/*
 * A number which isn't allocated, and can't be deallocated
 */
@interface NXNumberStatic : NXNumber
@end

/*
 * The zeros, which are equal: a signed integer, an unsigned integer and a floating point
 * number, so a zero keeps its kind
 */
@interface NXNumberZero : NXNumberStatic
@end

@interface NXNumberUnsignedZero : NXNumberZero
+ (NXNumber *)unsignedZeroValue;
@end

@interface NXNumberFloatZero : NXNumberZero
+ (NXNumber *)floatZeroValue;
@end

@interface NXNumberBool : NXNumberStatic {
@private
  BOOL _value;
}
@end

@interface NXNumberInt16 : NXNumber {
@private
  int16_t _value;
}
- (id)initWithInt16:(int16_t)value;
@end

@interface NXNumberUnsignedInt16 : NXNumber {
@private
  uint16_t _value;
}
- (id)initWithUnsignedInt16:(uint16_t)value;
@end

@interface NXNumberInt32 : NXNumber {
@private
  int32_t _value;
}
- (id)initWithInt32:(int32_t)value;
@end

@interface NXNumberUnsignedInt32 : NXNumber {
@private
  uint32_t _value;
}
- (id)initWithUnsignedInt32:(uint32_t)value;
@end

@interface NXNumberInt64 : NXNumber {
@private
  int64_t _value;
}
- (id)initWithInt64:(int64_t)value;
@end

@interface NXNumberUnsignedInt64 : NXNumber {
@private
  uint64_t _value;
}
- (id)initWithUnsignedInt64:(uint64_t)value;
@end

@interface NXNumberFloat32 : NXNumber {
@private
  float _value;
}
- (id)initWithFloat32:(float)value;
@end

@interface NXNumberFloat64 : NXNumber {
@private
  double _value;
}
- (id)initWithFloat64:(double)value;
@end

/*
 * The result of converting a floating point value to an integer
 */
typedef enum {
  NXFloatNotInteger, // It's out of range, or not a number
  NXFloatTruncated,  // It had a fraction, which was discarded
  NXFloatExact,
} NXFloatInteger;

/*
 * Returns the magnitude of a floating point value, as an integer, and whether it's
 * negative. They aren't set if it's out of range.
 */
NXFloatInteger NXFloatToInteger(double value, BOOL *negative,
                                uint64_t *magnitude);
