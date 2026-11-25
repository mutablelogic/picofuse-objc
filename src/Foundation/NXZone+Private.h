#pragma once
#include <Foundation/Foundation.h>

@interface NXZone (Private)

/*
 * Allocates a block of memory from the default zone, and sets zone to the default
 * zone, or to nil if there isn't one. The zone can't be deallocated before the
 * memory has been allocated, after which it's in use.
 */
+ (void *)allocWithSize:(size_t)size defaultZone:(NXZone **)zone;

@end
