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

/*
 * Changes the size of a block of memory from the zone, and returns where it now is, which
 * may be where it was, or NULL if there isn't enough memory, in which case it's
 * unchanged. It grows in place if it can, or else it's moved elsewhere in the zone, for
 * which the size it was is needed.
 */
- (void *)reallocWithSize:(size_t)size pointer:(void *)ptr oldSize:(size_t)oldSize;

@end

/*
 * Allocate and free memory in a zone, or if it's nil, with sys_malloc() and sys_free()
 */
static inline void *NXZoneAlloc(NXZone *zone, size_t size) {
  return zone == nil ? sys_malloc(size) : [zone allocWithSize:size];
}

static inline void *NXZoneRealloc(NXZone *zone, void *ptr, size_t oldSize,
                                  size_t size) {
  return zone == nil ? sys_realloc(ptr, size)
                     : [zone reallocWithSize:size pointer:ptr oldSize:oldSize];
}

static inline void NXZoneFree(NXZone *zone, void *ptr) {
  if (zone == nil) {
    sys_free(ptr);
  } else {
    [zone free:ptr];
  }
}
