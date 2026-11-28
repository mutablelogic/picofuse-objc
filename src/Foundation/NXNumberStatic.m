#include "NXNumber+Private.h"
#include "NXStatic.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

///////////////////////////////////////////////////////////////////////////////
// GLOBALS

static NXStatic zero_storage;
static NXStatic unsigned_zero_storage;
static NXStatic float_zero_storage;
static NXStatic true_storage;
static NXStatic false_storage;

@implementation NXNumberStatic

NX_STATIC_METHODS

@end

@implementation NXNumberZero

// This is before zeroValue can be called
+ (void)initialize {
  if (self == [NXNumberZero class]) {
    NXStaticInstance(&zero_storage, self);
  }
}

+ (NXNumber *)zeroValue {
  return (NXNumber *)(void *)&zero_storage;
}

- (NXString *)description {
  return @"0";
}

@end

@implementation NXNumberUnsignedZero

+ (void)initialize {
  if (self == [NXNumberUnsignedZero class]) {
    NXStaticInstance(&unsigned_zero_storage, self);
  }
}

+ (NXNumber *)unsignedZeroValue {
  return (NXNumber *)(void *)&unsigned_zero_storage;
}

- (BOOL)isUnsigned {
  return YES;
}

@end

@implementation NXNumberFloatZero

+ (void)initialize {
  if (self == [NXNumberFloatZero class]) {
    NXStaticInstance(&float_zero_storage, self);
  }
}

+ (NXNumber *)floatZeroValue {
  return (NXNumber *)(void *)&float_zero_storage;
}

- (BOOL)isFloat {
  return YES;
}

@end

@implementation NXNumberBool

// This is before trueValue and falseValue can be called
+ (void)initialize {
  if (self == [NXNumberBool class]) {
    NXNumberBool *number = NXStaticInstance(&true_storage, self);
    number->_value = YES;
    NXStaticInstance(&false_storage, self);
  }
}

+ (NXNumber *)trueValue {
  return (NXNumber *)(void *)&true_storage;
}

+ (NXNumber *)falseValue {
  return (NXNumber *)(void *)&false_storage;
}

- (BOOL)isNegative:(uint64_t *)magnitude {
  *magnitude = _value ? 1 : 0;
  return NO;
}

- (NXString *)description {
  return _value ? @"true" : @"false";
}

@end
