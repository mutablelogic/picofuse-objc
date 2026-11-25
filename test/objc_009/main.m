#include <test/test.h>

OBJC_ROOT_CLASS
@interface Root {
  Class isa;
}
+ (Class)me;
@end

@implementation Root
+ (Class)me {
  return self;
}
@end

@interface Left : Root
@end
@implementation Left
@end

@interface Right : Root
@end
@implementation Right
@end

@interface LeftLeaf : Left
@end
@implementation LeftLeaf
@end

static void check_superclass(const char *name, const char *superclass) {
  Class cls = objc_lookupClass(name);
  test_assert(cls != Nil);
  test_assert_strequal(class_getName(cls), name);
  test_assert([cls me] == cls);
  if (superclass == NULL) {
    test_assert(class_getSuperclass(cls) == Nil);
  } else {
    test_assert(class_getSuperclass(cls) == objc_lookupClass(superclass));
  }
}

test_main(0) {
  // The subclass first, so that looking it up has to resolve the others
  check_superclass("LeftLeaf", "Left");
  check_superclass("Left", "Root");
  check_superclass("Right", "Root");
  check_superclass("Root", NULL);
  test_assert(objc_lookupClass("Missing") == Nil);
  test_assert(objc_lookupClass(NULL) == Nil);

  Class protocol = objc_lookupClass("Protocol");
  test_assert(protocol != Nil);
  test_assert(class_getSuperclass(protocol) == objc_lookupClass("Object"));
}
