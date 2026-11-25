#include "NXNumber+Private.h"
#include <Foundation/Foundation.h>

@implementation NXNumberInt16

- (id)initWithInt16:(int16_t)value {
  self = [super init];
  if (self != nil) {
    _value = value;
  }
  return self;
}

- (BOOL)isNegative:(uint64_t *)magnitude {
  *magnitude = _value < 0 ? -(uint64_t)_value : (uint64_t)_value;
  return _value < 0;
}

@end

@implementation NXNumberUnsignedInt16

- (id)initWithUnsignedInt16:(uint16_t)value {
  self = [super init];
  if (self != nil) {
    _value = value;
  }
  return self;
}

- (BOOL)isNegative:(uint64_t *)magnitude {
  *magnitude = _value;
  return NO;
}

@end

@implementation NXNumberInt32

- (id)initWithInt32:(int32_t)value {
  self = [super init];
  if (self != nil) {
    _value = value;
  }
  return self;
}

- (BOOL)isNegative:(uint64_t *)magnitude {
  *magnitude = _value < 0 ? -(uint64_t)_value : (uint64_t)_value;
  return _value < 0;
}

@end

@implementation NXNumberUnsignedInt32

- (id)initWithUnsignedInt32:(uint32_t)value {
  self = [super init];
  if (self != nil) {
    _value = value;
  }
  return self;
}

- (BOOL)isNegative:(uint64_t *)magnitude {
  *magnitude = _value;
  return NO;
}

@end

@implementation NXNumberInt64

- (id)initWithInt64:(int64_t)value {
  self = [super init];
  if (self != nil) {
    _value = value;
  }
  return self;
}

- (BOOL)isNegative:(uint64_t *)magnitude {
  *magnitude = _value < 0 ? -(uint64_t)_value : (uint64_t)_value;
  return _value < 0;
}

@end

@implementation NXNumberUnsignedInt64

- (id)initWithUnsignedInt64:(uint64_t)value {
  self = [super init];
  if (self != nil) {
    _value = value;
  }
  return self;
}

- (BOOL)isNegative:(uint64_t *)magnitude {
  *magnitude = _value;
  return NO;
}

@end
