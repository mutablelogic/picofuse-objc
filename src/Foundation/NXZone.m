#include "NXZone+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

// Enough for what an arena uses to keep track of one allocation
#define ARENA_OVERHEAD 64

// The first zone which was created, unless it's since been deallocated. It's only
// changed, and memory is only allocated from it as the default zone, with the
// class locked.
static NXZone *volatile defaultZone = nil;

@implementation NXZone

///////////////////////////////////////////////////////////////////////////////
// PRIVATE METHODS

// Returns the last arena in the chain
static sys_mem_arena_t *last_arena(sys_mem_arena_t *arena) {
  sys_mem_arena_t *next;
  while ((next = sys_mem_arena_next(arena, NULL)) != NULL) {
    arena = next;
  }
  return arena;
}

// Returns the totals for all arenas in the chain
static sys_mem_stats_t arena_stats(sys_mem_arena_t *arena) {
  sys_mem_stats_t total = {0};
  while (arena != NULL) {
    sys_mem_stats_t stats = {0};
    arena = sys_mem_arena_next(arena, &stats);
    total.size_bytes += stats.size_bytes;
    total.used_bytes += stats.used_bytes;
    total.allocations += stats.allocations;
  }
  return total;
}

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

// A zone isn't itself allocated in a zone
+ (id)allocWithZone:(NXZone *)zone {
  if (zone != nil) {
    return nil;
  }

  NXZone *instance = sys_calloc(1, class_getInstanceSize(self));
  if (instance == NULL) {
    return nil;
  }
  object_setClass(instance, self);
  return [instance retain];
}

// There's nothing to be done with a zone which has no size
- (id)init {
  [self release];
  return nil;
}

+ (id)zoneWithSize:(size_t)size {
  NXZone *zone = [self alloc];
  if (zone == nil) {
    return nil;
  }

  zone->_size = size;
  zone->_arena = sys_mem_arena_init(size, NULL, sys_malloc, sys_free);
  if (zone->_arena == NULL) {
    [zone release];
    return nil;
  }

  @synchronized([NXZone class]) {
    if (defaultZone == nil) {
      defaultZone = zone;
    }
  }
  return zone;
}

- (void)dealloc {
  @synchronized([NXZone class]) {
    size_t count = [self count];
    if (count != 0) {
      sys_panicf("-[NXZone dealloc] called with %u allocations",
                 (unsigned)count);
    }
    if (defaultZone == self) {
      defaultZone = nil;
    }
  }

  // Only the last arena in a chain can be deleted
  while (_arena != NULL) {
    sys_mem_arena_t *last = last_arena(_arena);
    if (last == _arena) {
      _arena = NULL;
    }
    sys_mem_arena_delete(last);
  }

  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

+ (NXZone *)defaultZone {
  return defaultZone;
}

- (size_t)count {
  sys_mem_stats_t stats;
  @synchronized(self) {
    stats = arena_stats(_arena);
  }
  return stats.allocations;
}

- (size_t)bytesTotal {
  sys_mem_stats_t stats;
  @synchronized(self) {
    stats = arena_stats(_arena);
  }
  return stats.size_bytes;
}

- (size_t)bytesUsed {
  sys_mem_stats_t stats;
  @synchronized(self) {
    stats = arena_stats(_arena);
  }
  return stats.used_bytes;
}

- (size_t)bytesFree {
  sys_mem_stats_t stats;
  @synchronized(self) {
    stats = arena_stats(_arena);
  }
  return stats.size_bytes - stats.used_bytes;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

- (void *)allocWithSize:(size_t)size {
  if (size == 0) {
    return NULL;
  }

  void *ptr = NULL;
  @synchronized(self) {
    // Use the first arena with room
    sys_mem_arena_t *last = _arena;
    for (sys_mem_arena_t *arena = _arena; arena != NULL && ptr == NULL;
         arena = sys_mem_arena_next(arena, NULL)) {
      ptr = sys_mem_arena_alloc(arena, size);
      last = arena;
    }

    // Or else add another
    if (ptr == NULL && size <= SIZE_MAX - ARENA_OVERHEAD) {
      size_t required = size + ARENA_OVERHEAD;
      sys_mem_arena_t *arena = sys_mem_arena_init(
          required > _size ? required : _size, last, NULL, NULL);
      if (arena != NULL) {
        ptr = sys_mem_arena_alloc(arena, size);
      }
    }
  }
  return ptr;
}

- (void)free:(void *)ptr {
  if (ptr == NULL) {
    return;
  }

  // An arena ignores what it didn't allocate, so whether it did is known from
  // its number of allocations
  BOOL freed = NO;
  @synchronized(self) {
    sys_mem_arena_t *arena = _arena;
    while (arena != NULL && !freed) {
      sys_mem_stats_t before = {0}, after = {0};
      sys_mem_arena_next(arena, &before);
      sys_mem_arena_free(arena, ptr);
      arena = sys_mem_arena_next(arena, &after);
      freed = after.allocations != before.allocations;
    }
  }
  if (!freed) {
    sys_panicf("-[NXZone free:] memory @%p wasn't allocated by the zone", ptr);
  }
}

@end

@implementation NXZone (Private)

+ (void *)allocWithSize:(size_t)size defaultZone:(NXZone **)zone {
  *zone = nil;
  if (defaultZone == nil) {
    return NULL;
  }

  void *ptr = NULL;
  @synchronized([NXZone class]) {
    *zone = defaultZone;
    ptr = [*zone allocWithSize:size];
  }
  return ptr;
}

@end
