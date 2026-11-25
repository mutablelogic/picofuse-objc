#include "NXNumber+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

///////////////////////////////////////////////////////////////////////////////
// TYPES

// Room for an instance of any of the classes here
typedef union {
  uint64_t align;
  unsigned char bytes[64];
} storage_t;

///////////////////////////////////////////////////////////////////////////////
// GLOBALS

static storage_t zero_storage;
static storage_t true_storage;
static storage_t false_storage;

///////////////////////////////////////////////////////////////////////////////
// PRIVATE METHODS

// Make a static instance, which is already zero
static id static_instance(storage_t *storage, Class cls) {
  objc_assert(class_getInstanceSize(cls) <= sizeof(storage_t));
  id instance = (id)(void *)storage;
  object_setClass(instance, cls);
  return instance;
}

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
    static_instance(&zero_storage, self);
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
    NXNumberBool *number = static_instance(&true_storage, self);
    number->_value = YES;
    static_instance(&false_storage, self);
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
