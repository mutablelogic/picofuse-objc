#include <test/TestObject.h>
#include <test/test.h>

@protocol Weighing
- (int)weight;
@end

@interface Stone : TestObject
@end
@implementation Stone
@end

@interface Stone (Weight) <Weighing>
@end

@implementation Stone (Weight)
- (int)weight {
  return 14;
}
@end

test_main(0) {
  Stone *stone = [[Stone alloc] init];
  id<Weighing> object = stone;
  test_assert([object weight] == 14);
  test_assert([stone conformsTo:@protocol(Weighing)]);
  test_assert([Stone conformsTo:@protocol(Weighing)]);
  test_assert(![TestObject conformsTo:@protocol(Weighing)]);
  [stone free];
}
