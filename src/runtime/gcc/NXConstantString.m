#include <runtime/gcc/objc.h>
#include <string.h>

@implementation NXConstantString

////////////////////////////////////////////////////////////////////////////////////
// PROPERTIES

- (const char *)cStr {
  return _data;
}

- (unsigned int)length {
  return _length;
}

////////////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

- (id)retain {
  // NXConstantString is immutable, so we return self
  return self;
}

- (void)release {
  // NXConstantString is immutable, so we do nothing
}

- (BOOL)isEqual:(id)anObject {
  if (self == anObject) {
    return YES;
  }
  if ([anObject class] == [self class]) {
    if (self->_length != ((NXConstantString *)anObject)->_length) {
      return NO;
    }
    return (memcmp(self->_data, ((NXConstantString *)anObject)->_data,
                       self->_length) == 0);
  }
  return NO;
}

@end
