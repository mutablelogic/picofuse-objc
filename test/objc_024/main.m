#include <test/test.h>

// This module has the method of the class, and only knows of that one

int wide_value(void);
int narrow_value(void);

@interface Base : Object
+ (int)value:(int)number;
@end

@implementation Base
+ (int)value:(int)number {
  return -number;
}
@end

@interface Thing : Base
@end

@implementation Thing
+ (int)value:(int)number {
  return number;
}
@end

int narrow_value(void) { return [Thing value:5]; }

test_main(0) {
  // Each caller gets the method which has the types it was compiled with, and
  // neither gets that of the superclass
  for (int i = 0; i < 2; i++) {
    test_assert(narrow_value() == 5);
    test_assert(wide_value() == 1005);
  }

  // Where there are no types, it's the category's, which came last. This is how a
  // selector is laid out: whether @selector has types depends on the compiler.
  struct {
    const char *name;
    const char *types;
  } untyped = {"value:", NULL};
  SEL selector = (SEL)(void *)&untyped;
  id cls = (id)[Thing class];
  int (*imp)(id, SEL, long long) = (int (*)(id, SEL, long long))(void (*)(void))
      objc_msg_lookup(cls, selector);
  test_assert(imp(cls, selector, 7) == 1007);
}
