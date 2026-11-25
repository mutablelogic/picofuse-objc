#include <test/test.h>

static int calls = 0;
static Class last = Nil;

OBJC_ROOT_CLASS
@interface Parent {
  Class isa;
}
+ (void)initialize;
+ (int)calls;
+ (Class)me;
@end

@implementation Parent
+ (void)initialize {
  calls++;
  last = self;
}
+ (int)calls {
  return calls;
}
+ (Class)me {
  return self;
}
@end

@interface Child : Parent
@end
@implementation Child
@end

test_main(0) {
  test_assert(calls == 0);
  test_assert([Parent calls] == 1);
  test_assert(last == [Parent me]);
  test_assert([Child calls] == 2);
  test_assert(last == [Child me]);
  test_assert([Child calls] == 2);
}
