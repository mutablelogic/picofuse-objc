#pragma once
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

/*
 * Room for an instance of a small class, which is static and so isn't allocated, and
 * has no header
 */
typedef union {
  uint64_t align;
  unsigned char bytes[64];
} NXStatic;

/*
 * Make an instance of a class in static storage. Its instance variables are zero.
 */
static inline id NXStaticInstance(NXStatic *storage, Class cls) {
  objc_assert(class_getInstanceSize(cls) <= sizeof(NXStatic));
  id instance = (id)(void *)storage;
  object_setClass(instance, cls);
  return instance;
}

/*
 * The methods of a class whose instances are static. They're never deallocated, so
 * they aren't retained.
 */
#define NX_STATIC_METHODS                                                      \
  -(id)retain {                                                                \
    return self;                                                               \
  }                                                                            \
  -(void)release {                                                             \
  }                                                                            \
  -(id)autorelease {                                                           \
    return self;                                                               \
  }                                                                            \
  -(NXZone *)zone {                                                            \
    return nil;                                                                \
  }                                                                            \
  -(void)dealloc {                                                             \
    sys_panicf("-[%s dealloc] can't be deallocated",                           \
               object_getClassName(self));                                     \
    [super dealloc];                                                           \
  }
