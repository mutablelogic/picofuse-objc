#include <test/TestObject.h>
#include <test/test.h>

@protocol Opening
- (void)open;
@end

@protocol Reading <Opening>
- (int)read;
@end

@interface Book : TestObject <Reading> {
@public
  BOOL opened;
}
@end

@implementation Book
- (void)open {
  opened = YES;
}
- (int)read {
  return opened ? 1 : 0;
}
@end

test_main(0) {
  Book *book = [[Book alloc] init];
  id<Reading> object = book;
  test_assert([object read] == 0);
  [object open];
  test_assert(book->opened);
  test_assert([object read] == 1);

  test_assert([book conformsTo:@protocol(Reading)]);
  test_assert([book conformsTo:@protocol(Opening)]);
  test_assert([@protocol(Reading) conformsTo:@protocol(Opening)]);
  test_assert(![@protocol(Opening) conformsTo:@protocol(Reading)]);
  [book free];
}
