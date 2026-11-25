#pragma once
#include <Foundation/Foundation.h>

/*
 * Room for an instance of a small class, which is static and so isn't allocated
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
