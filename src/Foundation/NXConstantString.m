#include "NXStatic.h"
#include <Foundation/Foundation.h>

@implementation NXConstantString

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

// Only the compiler makes them
+ (id)allocWithZone:(NXZone *)zone {
  (void)zone;
  return nil;
}

NX_STATIC_METHODS

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

- (size_t)length {
  return _length;
}

- (const char *)cStr {
  return _data;
}

@end
