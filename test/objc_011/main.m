#include <test/test.h>

@interface Names : Object
+ (const char *)plain;
+ (const char *)with:(int)a and:(int)b;
@end

@implementation Names
+ (const char *)plain {
  return sel_getName(_cmd);
}
+ (const char *)with:(int)a and:(int)b {
  test_assert(a == 1 && b == 2);
  return sel_getName(_cmd);
}
@end

test_main(0) {
  test_assert_strequal([Names plain], "plain");
  test_assert_strequal([Names with:1 and:2], "with:and:");
  test_assert_strequal(sel_getName(@selector(isEqual:)), "isEqual:");
  test_assert(sel_getName(NULL) == NULL);
}
