#include "NXNumber+Private.h"
#include "NXStatic.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

///////////////////////////////////////////////////////////////////////////////
// GLOBALS

static NXStatic zero_storage;
static NXStatic true_storage;
static NXStatic false_storage;

@implementation NXNumberStatic

- (id)retain {
  return self;
}

- (void)release {
  // It's never deallocated
}

- (id)autorelease {
  return self;
}

- (void)dealloc {
  sys_panicf("-[%s dealloc] can't be deallocated", object_getClassName(self));
  [super dealloc];
}

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

@end
