#include <test/TestObject.h>
#include <test/test.h>

@interface Base : TestObject {
  int _base;
}
- (id)initWithValue:(int)value;
- (int)base;
- (void)setBase:(int)value;
- (int)value;
@end

@implementation Base
- (id)initWithValue:(int)value {
  self = [super init];
  if (self != nil) {
    _base = value;
  }
  return self;
}
- (int)base {
  return _base;
}
- (void)setBase:(int)value {
  _base = value;
}
- (int)value {
  return _base;
}
@end

@interface Derived : Base {
  int _derived;
}
- (void)setDerived:(int)value;
@end

@implementation Derived
- (id)initWithValue:(int)value {
  self = [super initWithValue:value];
  if (self != nil) {
    _derived = value * 10;
  }
  return self;
}
- (void)setDerived:(int)value {
  _derived = value;
}
- (int)value {
  return [super value] + _derived;
}
@end

test_main(0) {
  Base *base = [[Base alloc] initWithValue:1];
  Derived *derived = [[Derived alloc] initWithValue:2];
  Base *as_base = derived;

  test_assert([base value] == 1);
  test_assert([derived base] == 2);
  test_assert([derived value] == 22);

  // The instance's class decides which method is called, not the variable's
  test_assert([as_base value] == 22);

  // The variables of one class and instance don't disturb another's
  [derived setDerived:100];
  test_assert([derived base] == 2 && [derived value] == 102);
  [derived setBase:5];
  test_assert([derived value] == 105);
  test_assert([base value] == 1);

  [derived free];
  [base free];
}
