#include "NXNumber+Private.h"
#include "NXObject+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <string.h>

///////////////////////////////////////////////////////////////////////////////
// PRIVATE METHODS

// Returns the value of a number which isn't greater than the maximum, and which if
// it's negative, isn't less than the minimum
static int64_t signed_value(NXNumber *number, int64_t min, int64_t max,
                            const char *method) {
  uint64_t magnitude;
  BOOL negative = [number isNegative:&magnitude];
  if (magnitude > (negative ? -(uint64_t)min : (uint64_t)max)) {
    sys_panicf("-[%s %s] value is out of range", object_getClassName(number),
               method);
  }

  // The magnitude of the minimum doesn't fit into an int64_t
  return negative ? -(int64_t)(magnitude - 1) - 1 : (int64_t)magnitude;
}

// Returns the value of a number which isn't negative or greater than the maximum
static uint64_t unsigned_value(NXNumber *number, uint64_t max,
                               const char *method) {
  uint64_t magnitude;
  BOOL negative = [number isNegative:&magnitude];
  if (negative || magnitude > max) {
    sys_panicf("-[%s %s] value is out of range", object_getClassName(number),
               method);
  }
  return magnitude;
}

// Returns YES if a number has the value of an integer, and that integer
static BOOL exact_value(NXNumber *number, BOOL *negative, uint64_t *magnitude) {
  if ([number isFloat]) {
    return NXFloatToInteger([number float64Value], negative, magnitude) ==
           NXFloatExact;
  }
  *negative = [number isNegative:magnitude];
  return YES;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

// Returns YES if a string is an integer in hex, binary or octal, which can't
// be read as a float
static BOOL is_based_integer(const char *cStr, size_t length) {
  size_t i = (length > 0 && (cStr[0] == '+' || cStr[0] == '-')) ? 1 : 0;
  if (length < i + 2 || cStr[i] != '0') {
    return NO;
  }
  char c = cStr[i + 1];
  if (c == 'x' || c == 'X' || c == 'b' || c == 'B' || c == 'o' || c == 'O') {
    return YES;
  }

  // "0755" is octal, but "0755.5" and "07e5" are floats
  for (size_t j = i + 1; j < length; j++) {
    if (cStr[j] < '0' || cStr[j] > '9') {
      return NO;
    }
  }
  return YES;
}

int32_t NXRandInt32(void) { return (int32_t)sys_random_uint32(); }

uint32_t NXRandUnsignedInt32(void) { return sys_random_uint32(); }

int64_t NXRandInt64(void) { return (int64_t)sys_random_uint64(); }

uint64_t NXRandUnsignedInt64(void) { return sys_random_uint64(); }

@implementation NXNumber

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

+ (NXNumber *)trueValue {
  return [NXNumberBool trueValue];
}

+ (NXNumber *)falseValue {
  return [NXNumberBool falseValue];
}

+ (NXNumber *)zeroValue {
  return [NXNumberZero zeroValue];
}

+ (NXNumber *)numberWithString:(NXString *)string {
  const char *cStr = [string cStr];
  size_t length = [string length];

  // A constant string can have a zero in it, which ends a number early
  if (length == 0 || strnlen(cStr, length) != length) {
    return nil;
  }
  bool boolean;
  int64_t signed_value;
  uint64_t unsigned_value;
  double float_value;
  if (sys_string_parse_bool(cStr, length, &boolean)) {
    return [self numberWithBool:boolean];
  } else if (sys_string_parse_int64(cStr, length, &signed_value)) {
    return [self numberWithInt64:signed_value];
  } else if (sys_string_parse_uint64(cStr, length, &unsigned_value)) {
    return [self numberWithUnsignedInt64:unsigned_value];
  } else if (!is_based_integer(cStr, length) &&
             sys_string_parse_float64(cStr, length, &float_value)) {
    return [self numberWithFloat64:float_value];
  }
  return nil;
}

+ (NXNumber *)numberWithBool:(BOOL)value {
  return value ? [NXNumberBool trueValue] : [NXNumberBool falseValue];
}

+ (NXNumber *)numberWithInt16:(int16_t)value {
  if (value == 0) {
    return [NXNumberZero zeroValue];
  }
  return [[[NXNumberInt16 alloc] initWithInt16:value] autorelease];
}

+ (NXNumber *)numberWithUnsignedInt16:(uint16_t)value {
  if (value == 0) {
    return [NXNumberZero zeroValue];
  }
  return [[[NXNumberUnsignedInt16 alloc] initWithUnsignedInt16:value] autorelease];
}

+ (NXNumber *)numberWithInt32:(int32_t)value {
  if (value == 0) {
    return [NXNumberZero zeroValue];
  }
  return [[[NXNumberInt32 alloc] initWithInt32:value] autorelease];
}

+ (NXNumber *)numberWithUnsignedInt32:(uint32_t)value {
  if (value == 0) {
    return [NXNumberZero zeroValue];
  }
  return [[[NXNumberUnsignedInt32 alloc] initWithUnsignedInt32:value] autorelease];
}

+ (NXNumber *)numberWithInt64:(int64_t)value {
  if (value == 0) {
    return [NXNumberZero zeroValue];
  }
  return [[[NXNumberInt64 alloc] initWithInt64:value] autorelease];
}

+ (NXNumber *)numberWithUnsignedInt64:(uint64_t)value {
  if (value == 0) {
    return [NXNumberZero zeroValue];
  }
  return [[[NXNumberUnsignedInt64 alloc] initWithUnsignedInt64:value] autorelease];
}

+ (NXNumber *)numberWithFloat32:(float)value {
  if (value == 0 && !__builtin_signbit(value)) {
    return [NXNumberZero zeroValue];
  }
  return [[[NXNumberFloat32 alloc] initWithFloat32:value] autorelease];
}

+ (NXNumber *)numberWithFloat64:(double)value {
  if (value == 0 && !__builtin_signbit(value)) {
    return [NXNumberZero zeroValue];
  }
  return [[[NXNumberFloat64 alloc] initWithFloat64:value] autorelease];
}

+ (NXNumber *)randomInt32 {
  return [self numberWithInt32:NXRandInt32()];
}

+ (NXNumber *)randomUnsignedInt32 {
  return [self numberWithUnsignedInt32:NXRandUnsignedInt32()];
}

+ (NXNumber *)randomInt64 {
  return [self numberWithInt64:NXRandInt64()];
}

+ (NXNumber *)randomUnsignedInt64 {
  return [self numberWithUnsignedInt64:NXRandUnsignedInt64()];
}

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

- (BOOL)boolValue {
  uint64_t magnitude;
  [self isNegative:&magnitude];
  return magnitude != 0;
}

- (int16_t)int16Value {
  return (int16_t)signed_value(self, INT16_MIN, INT16_MAX, "int16Value");
}

- (uint16_t)unsignedInt16Value {
  return (uint16_t)unsigned_value(self, UINT16_MAX, "unsignedInt16Value");
}

- (int32_t)int32Value {
  return (int32_t)signed_value(self, INT32_MIN, INT32_MAX, "int32Value");
}

- (uint32_t)unsignedInt32Value {
  return (uint32_t)unsigned_value(self, UINT32_MAX, "unsignedInt32Value");
}

- (int64_t)int64Value {
  return (int64_t)signed_value(self, INT64_MIN, INT64_MAX, "int64Value");
}

- (uint64_t)unsignedInt64Value {
  return (uint64_t)unsigned_value(self, UINT64_MAX, "unsignedInt64Value");
}

- (float)float32Value {
  uint64_t magnitude;
  BOOL negative = [self isNegative:&magnitude];
  return negative ? -(float)magnitude : (float)magnitude;
}

- (double)float64Value {
  uint64_t magnitude;
  BOOL negative = [self isNegative:&magnitude];
  return negative ? -(double)magnitude : (double)magnitude;
}

- (NXString *)description {
  uint64_t magnitude;
  BOOL negative = [self isNegative:&magnitude];
  return [NXString
      stringWithFormat:@"%s%lu", negative ? "-" : "", magnitude];
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

- (uintptr_t)hash {
  // Those which are integers, whatever their type, as they're equal
  BOOL negative;
  uint64_t magnitude;
  if (exact_value(self, &negative, &magnitude)) {
    uintptr_t hash = NXHashFold(magnitude);
    return negative ? ~hash : hash;
  }
  double value = [self float64Value];
  uint64_t bits;
  memcpy(&bits, &value, sizeof(bits));
  return NXHashFold(bits);
}

- (BOOL)isEqual:(id)anObject {
  if (self == anObject) {
    return YES;
  }
  if (!object_isKindOfClass(anObject, [NXNumber class])) {
    return NO;
  }
  NXNumber *number = (NXNumber *)anObject;
  if ([self isFloat] && [number isFloat]) {
    return [self float64Value] == [number float64Value];
  }
  uint64_t magnitude, other;
  BOOL negative, other_negative;
  return exact_value(self, &negative, &magnitude) &&
         exact_value(number, &other_negative, &other) &&
         negative == other_negative && magnitude == other;
}

@end

@implementation NXNumber (Private)

- (BOOL)isNegative:(uint64_t *)magnitude {
  *magnitude = 0;
  return NO;
}

- (BOOL)isFloat {
  return NO;
}

@end
