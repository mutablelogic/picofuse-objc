#include <string.h>
#include <test/TestString.h>

@implementation TestString

- (const char *)cStr {
  return _data;
}

- (unsigned int)length {
  return _length;
}

- (BOOL)isEqual:(id)anObject {
  if (!object_isKindOfClass(anObject, [TestString class])) {
    return NO;
  }
  TestString *other = (TestString *)anObject;
  return _length == other->_length && memcmp(_data, other->_data, _length) == 0;
}

@end
