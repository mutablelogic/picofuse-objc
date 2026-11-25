#pragma once
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <stddef.h>

/*
 * What's kept in memory just before each instance of NXObject which is allocated. It's
 * aligned so that the instance is also.
 */
typedef struct {
  _Alignas(max_align_t) NXZone *zone; // Zone it was allocated in, or nil
  sys_atomic_t retain;                // Retain count
} NXObjectHeader;

/*
 * Returns the header of an instance
 */
static inline NXObjectHeader *NXObjectGetHeader(NXObject *object) {
  return (NXObjectHeader *)(void *)object - 1;
}

/*
 * Returns the size of the memory for an instance of a class, with its header
 */
static inline size_t NXObjectSize(Class cls) {
  return sizeof(NXObjectHeader) + class_getInstanceSize(cls);
}

/*
 * Make an instance of a class in memory, which is of the size above, and is zero. Its
 * retain count is one.
 */
static inline id NXObjectCreate(void *memory, Class cls, NXZone *zone) {
  NXObjectHeader *header = memory;
  header->zone = zone;
  sys_atomic_init(&header->retain, 1);
  id object = (id)(void *)(header + 1);
  object_setClass(object, cls);
  return object;
}
