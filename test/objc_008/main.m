#include <test/test.h>

struct pair {
  int first;
  int second;
};

static int steps = 0;

// The same method name as Counter, as an instance method returning a struct
@interface Decoy : Object
- (struct pair)measure;
@end

@implementation Decoy
- (struct pair)measure {
  struct pair result = {-1, -1};
  return result;
}
@end

@interface Pairs : Object
+ (struct pair)both;
@end

@implementation Pairs
+ (struct pair)both {
  struct pair result = {3, 5};
  return result;
}
@end

@interface Counter : Object
+ (id)first;
+ (id)second;
+ (int)measure;
+ (int)measureSelf;
+ (int)sumOfPairs;
@end

@implementation Counter
+ (id)first {
  test_assert(++steps == 1);
  return self;
}
+ (id)second {
  test_assert(++steps == 2);
  return self;
}
+ (int)measure {
  return 9;
}
+ (int)measureSelf {
  return [self measure];
}
+ (int)sumOfPairs {
  self = [Pairs class];
  struct pair result = [(Class)self both];
  return result.first + result.second;
}
@end

static id counter(void) { return [Counter class]; }

test_main(0) {
  test_assert([[Counter first] second] == [Counter class]);
  test_assert(steps == 2);
  test_assert([Counter measureSelf] == 9);
  test_assert([counter() sumOfPairs] == 8);
}
