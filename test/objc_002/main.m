#include <test/test.h>

static int parent_count = 0; // +initialize for Parent itself
static int child_count = 0;
static Class parent_self = Nil;
static Class child_self = Nil;
static int parent_order = 0;
static int child_order = 0;
static int order = 0;

@interface Parent : Object
+ (int)value;
@end

@implementation Parent
+ (void)initialize {
  parent_count++;
  parent_self = self;
  parent_order = ++order;
}
+ (int)value {
  return parent_count;
}
@end

@interface Child : Parent
+ (int)value;
@end

@implementation Child
+ (void)initialize {
  child_count++;
  child_self = self;
  child_order = ++order;
}
+ (int)value {
  return child_count;
}
@end

test_main(0) {
  // Nothing is initialized until it's sent a message
  test_assert(parent_count == 0 && child_count == 0);

  // Both are initialized before the method is called, superclass first
  test_assert([Child value] == 1);
  test_assert(parent_count == 1);
  test_assert(parent_order == 1 && child_order == 2);

  // Only once
  test_assert([Child value] == 1);
  test_assert([Parent value] == 1);

  // The receiver is the class, and not the metaclass
  test_assert(parent_self == [Parent class]);
  test_assert(child_self == [Child class]);
}
