#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <string.h>

@implementation NXString

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

- (size_t)length {
  sys_panicf("-[%s length] isn't implemented", object_getClassName(self));
}

- (const char *)cStr {
  sys_panicf("-[%s cStr] isn't implemented", object_getClassName(self));
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

- (BOOL)isEqual:(id)anObject {
  if (self == anObject) {
    return YES;
  }
  if (!object_isKindOfClass(anObject, [NXString class])) {
    return NO;
  }
  NXString *other = (NXString *)anObject;
  size_t length = [self length];
  return [other length] == length &&
         memcmp([self cStr], [other cStr], length) == 0;
}

@end
