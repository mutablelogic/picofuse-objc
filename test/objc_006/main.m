#include <test/TestObject.h>
#include <test/test.h>

@interface Person : TestObject {
  NXConstantString *_title;
}
- (id)initWithTitle:(NXConstantString *)title;
@end

@implementation Person
- (id)initWithTitle:(NXConstantString *)title {
  self = [super init];
  if (self != nil) {
    _title = title;
  }
  return self;
}
@end

@interface Person (Title)
- (NXConstantString *)title;
+ (int)legs;
@end

@implementation Person (Title)
- (NXConstantString *)title {
  return _title;
}
+ (int)legs {
  return 2;
}
@end

@interface Object (Counting)
- (int)increment;
@end

static int count = 0;

@implementation Object (Counting)
- (int)increment {
  return ++count;
}
@end

test_main(0) {
  Person *person = [[Person alloc] initWithTitle:@"Dr"];
  test_assert([[person title] isEqual:@"Dr"]);
  test_assert([Person legs] == 2);

  // Inherited from the category of the root class
  test_assert([person increment] == 1);
  test_assert([@"string" increment] == 2);
  [person free];
}
