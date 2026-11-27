// Listing the classes which are registered
#include <runtime/gcc/runtime.h>
#include <test/test.h>
#include <runtime/gcc/Object.h>

@interface Base : Object
@end
@implementation Base
@end

@interface Derived : Base
@end
@implementation Derived
@end

test_main(0) {
  size_t count = objc_getClassList(NULL, 0);
  test_assert(count >= 3);

  // Only as many as fit
  Class one[1] = {Nil};
  test_assert(objc_getClassList(one, 1) == count && one[0] != Nil);

  // Each once, with its name, and resolved: its superclass is a class
  Class classes[256];
  test_assert(count <= 256);
  test_assert(objc_getClassList(classes, 256) == count);
  BOOL base = NO, derived = NO;
  for (size_t i = 0; i < count; i++) {
    test_assert(classes[i] != Nil && class_getName(classes[i]) != NULL);
    test_assert(objc_lookupClass(class_getName(classes[i])) == classes[i]);
    for (size_t j = 0; j < i; j++) {
      test_assert(classes[j] != classes[i]);
    }
    if (classes[i] == [Base class]) {
      base = YES;
    }
    if (classes[i] == [Derived class]) {
      derived = YES;
      test_assert(class_getSuperclass(classes[i]) == [Base class]);
    }
  }
  test_assert(base && derived);
}
