#pragma once
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

@interface NXZone (Private)

/*
 * Allocates a block of memory from the default zone, and sets zone to the default
 * zone, or to nil if there isn't one. The zone can't be deallocated before the
 * memory has been allocated, after which it's in use.
 */
+ (void *)allocWithSize:(size_t)size defaultZone:(NXZone **)zone;

@end

/*
 * Allocate and free memory in a zone, or if it's nil, with sys_malloc() and sys_free()
 */
static inline void *NXZoneAlloc(NXZone *zone, size_t size) {
  return zone == nil ? sys_malloc(size) : [zone allocWithSize:size];
}

static inline void NXZoneFree(NXZone *zone, void *ptr) {
  if (zone == nil) {
    sys_free(ptr);
  } else {
    [zone free:ptr];
  }
}
