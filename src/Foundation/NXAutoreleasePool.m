#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

///////////////////////////////////////////////////////////////////////////////
// TYPES

// Number of objects in a page
#define PAGE_CAPACITY 16

// Objects are kept in pages, each of which is full other than the last
struct NXAutoreleasePage {
  struct NXAutoreleasePage *previous;
  size_t count;
  id objects[PAGE_CAPACITY];
};

///////////////////////////////////////////////////////////////////////////////
// GLOBALS

// The current pool of each thread. On a Pico, there's one thread per core.
#ifdef SYSTEM_NAME_PICO
#define CORES 2
static NXAutoreleasePool *currentPools[CORES];
#else
static __thread NXAutoreleasePool *currentPool = nil;
#endif

///////////////////////////////////////////////////////////////////////////////
// PRIVATE METHODS

// Returns a pointer to the current pool of the calling thread
static inline NXAutoreleasePool **current_pool(void) {
#ifdef SYSTEM_NAME_PICO
  uint8_t core = sys_thread_core();
  objc_assert(core < CORES);
  return &currentPools[core];
#else
  return &currentPool;
#endif
}

@interface NXAutoreleasePool (Private)
- (void)addPage;
- (void)freePage;
@end

@implementation NXAutoreleasePool

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

- (id)init {
  self = [super init];
  if (self != nil) {
    NXAutoreleasePool **current = current_pool();
    _previous = *current;
    *current = self;
  }
  return self;
}

- (void)dealloc {
  NXAutoreleasePool **current = current_pool();
  if (*current != self) {
    sys_panicf("-[NXAutoreleasePool dealloc] pool isn't the current pool of the "
               "thread");
  }

  // Drain while this is still the current pool, so that what's autoreleased
  // meanwhile is added to it. The page that's left is empty.
  [self drain];
  if (_page != NULL) {
    [self freePage];
  }
  *current = _previous;
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

+ (NXAutoreleasePool *)currentPool {
  return *current_pool();
}

- (size_t)count {
  size_t count = 0;
  for (struct NXAutoreleasePage *page = _page; page != NULL;
       page = page->previous) {
    count += page->count;
  }
  return count;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

- (void)addObject:(id)object {
  if (object == nil) {
    return;
  }
  if (!object_isKindOfClass(object, [NXObject class])) {
    sys_panicf("-[NXAutoreleasePool addObject:] %s isn't an NXObject",
               object_getClassName(object));
  }
  if (_page == NULL || _page->count == PAGE_CAPACITY) {
    [self addPage];
  }
  _page->objects[_page->count++] = object;
}

- (void)drain {
  // Releasing an object can add others to the pool, so there's no telling what's
  // last until each has been removed. One empty page is kept, to use again.
  while (_page != NULL) {
    if (_page->count > 0) {
      id object = _page->objects[--_page->count];
      [(NXObject *)object release];
    } else if (_page->previous != NULL) {
      [self freePage];
    } else {
      break;
    }
  }
}

// A pool is released by whoever made it
- (id)retain {
  sys_panicf("-[NXAutoreleasePool retain] pools can't be retained");
}

- (id)autorelease {
  sys_panicf("-[NXAutoreleasePool autorelease] pools can't be autoreleased");
}

@end

///////////////////////////////////////////////////////////////////////////////
// PRIVATE METHODS

@implementation NXAutoreleasePool (Private)

// Add an empty page, in the same zone as the pool
- (void)addPage {
  size_t size = sizeof(struct NXAutoreleasePage);
  NXZone *zone = [self zone];
  struct NXAutoreleasePage *page =
      zone == nil ? sys_malloc(size) : [zone allocWithSize:size];
  if (page == NULL) {
    sys_panicf("-[NXAutoreleasePool addObject:] out of memory");
  }
  page->previous = _page;
  page->count = 0;
  _page = page;
}

// Free the last page
- (void)freePage {
  struct NXAutoreleasePage *page = _page;
  _page = page->previous;
  NXZone *zone = [self zone];
  if (zone == nil) {
    sys_free(page);
  } else {
    [zone free:page];
  }
}

@end
