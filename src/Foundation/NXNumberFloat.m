#include "NXNumber+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

_Static_assert(sizeof(float) == 4 && sizeof(double) == 8,
               "float and double are 32 and 64 bits");

// Two to the power of 64, which is one more than the largest magnitude
#define MAGNITUDE_LIMIT 18446744073709551616.0

///////////////////////////////////////////////////////////////////////////////
// PRIVATE METHODS

NXFloatInteger NXFloatToInteger(double value, BOOL *negative,
                                uint64_t *magnitude) {
  double absolute = value < 0 ? -value : value;
  if (!(absolute < MAGNITUDE_LIMIT)) { // This is also if it's not a number
    return NXFloatNotInteger;
  }
  *magnitude = (uint64_t)absolute;
  *negative = value < 0 && *magnitude != 0;
  return (double)*magnitude == absolute ? NXFloatExact : NXFloatTruncated;
}

// Returns the magnitude, for a number which has to be in range
static BOOL magnitude_of(NXNumber *number, uint64_t *magnitude) {
  BOOL negative = NO;
  if (NXFloatToInteger([number float64Value], &negative, magnitude) ==
      NXFloatNotInteger) {
    sys_panicf("-[%s] value is out of range for an integer",
               object_getClassName(number));
  }
  return negative;
}

@implementation NXNumberFloat32

- (id)initWithFloat32:(float)value {
  self = [super init];
  if (self != nil) {
    _value = value;
  }
  return self;
}

- (BOOL)isFloat {
  return YES;
}

- (BOOL)isNegative:(uint64_t *)magnitude {
  return magnitude_of(self, magnitude);
}

- (BOOL)boolValue {
  return _value != 0;
}

- (float)float32Value {
  return _value;
}

- (double)float64Value {
  return _value;
}

@end

@implementation NXNumberFloat64

- (id)initWithFloat64:(double)value {
  self = [super init];
  if (self != nil) {
    _value = value;
  }
  return self;
}

- (BOOL)isFloat {
  return YES;
}

- (BOOL)isNegative:(uint64_t *)magnitude {
  return magnitude_of(self, magnitude);
}

- (BOOL)boolValue {
  return _value != 0;
}

- (float)float32Value {
  return (float)_value;
}

- (double)float64Value {
  return _value;
}

@end
