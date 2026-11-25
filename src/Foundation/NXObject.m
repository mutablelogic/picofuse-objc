#include "NXObject+Private.h"
#include "NXZone+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <string.h>

// Object doesn't have this method, so it's never called. GCC warns about any
// dealloc which doesn't call that of the superclass, so there's an unreachable
// call below.
@interface Object (Dealloc)
- (void)dealloc;
@end

@implementation NXObject

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

+ (id)alloc {
  return [self allocWithZone:nil];
}

+ (id)allocWithZone:(NXZone *)zone {
  size_t size = NXObjectSize(self);
  void *memory;
  if (zone == nil) {
    memory = [NXZone allocWithSize:size defaultZone:&zone];
  } else {
    memory = [zone allocWithSize:size];
  }
  if (zone == nil) {
    memory = sys_calloc(1, size);
  } else if (memory != NULL) {
    memset(memory, 0, size);
  }
  return memory == NULL ? nil : NXObjectCreate(memory, self, zone);
}

- (void)dealloc {
  NXObjectHeader *header = NXObjectGetHeader(self);
  uint32_t count = sys_atomic_get(&header->retain);
  if (count != 0) {
    sys_panicf("-[%s dealloc] called with a retain count of %u",
               object_getClassName(self), (unsigned)count);
  }
  if (header->zone == nil) {
    sys_free(header);
  } else {
    [header->zone free:header];
  }
  if (NO) {
    [super dealloc];
  }
}

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

- (NXZone *)zone {
  return NXObjectGetHeader(self)->zone;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

- (id)retain {
  sys_atomic_inc(&NXObjectGetHeader(self)->retain);
  return self;
}

- (void)release {
  // What other threads did with the object before they released it has to be
  // seen by the one that deallocates it
  __atomic_thread_fence(__ATOMIC_RELEASE);
  uint32_t count = sys_atomic_dec(&NXObjectGetHeader(self)->retain);
  if (count == UINT32_MAX) {
    sys_panicf("-[%s release] called with a retain count of zero",
               object_getClassName(self));
  }
  if (count == 0) {
    __atomic_thread_fence(__ATOMIC_ACQUIRE);
    [self dealloc];
  }
}

- (id)autorelease {
  NXAutoreleasePool *pool = [NXAutoreleasePool currentPool];
  if (pool == nil) {
    sys_panicf("-[%s autorelease] called without an autorelease pool",
               object_getClassName(self));
  }
  [pool addObject:self];
  return self;
}

@end
