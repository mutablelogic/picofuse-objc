#include <test/TestObject.h>
#include <test/test.h>

@interface Lamp : TestObject {
  int _level;
}
+ (id)lamp;
- (int)level;
- (void)setLevel:(int)level;
@end

@implementation Lamp
+ (id)lamp {
  return [[self alloc] init];
}
- (int)level {
  return _level;
}
- (void)setLevel:(int)level {
  _level = level;
}
@end

test_main(0) {
  Class cls = [Lamp class];
  test_assert(class_respondsToSelector(cls, @selector(level)));
  test_assert(class_respondsToSelector(cls, @selector(setLevel:)));
  test_assert(class_respondsToSelector(cls, @selector(isEqual:)));
  test_assert(!class_respondsToSelector(cls, @selector(lamp)));
  test_assert(!class_respondsToSelector(cls, @selector(cStr)));
  test_assert(class_metaclassRespondsToSelector(cls, @selector(lamp)));
  test_assert(!class_metaclassRespondsToSelector(cls, @selector(level)));

  Lamp *lamp = [Lamp lamp];
  [lamp setLevel:7];
  test_assert([lamp level] == 7);
  test_assert([lamp respondsToSelector:@selector(level)]);
  test_assert(![lamp respondsToSelector:@selector(cStr)]);
  [lamp free];
}
