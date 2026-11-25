#include "NXStatic.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

static NXStatic null_storage;

@implementation NXNull

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

// This is before nullValue can be called
+ (void)initialize {
  if (self == [NXNull class]) {
    NXStaticInstance(&null_storage, self);
  }
}

+ (NXNull *)nullValue {
  return (NXNull *)(void *)&null_storage;
}

// There's only ever one
+ (id)allocWithZone:(NXZone *)zone {
  (void)zone;
  return [NXNull nullValue];
}

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
  sys_panicf("-[NXNull dealloc] can't be deallocated");
  [super dealloc];
}

@end
