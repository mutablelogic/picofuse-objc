#include <test/TestObject.h>
#include <test/test.h>

// Replacing methods of the class is the point
#ifdef __clang__
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#endif

@interface Animal : TestObject
+ (int)noise;
- (int)legs;
@end

@implementation Animal
+ (int)noise {
  return 1;
}
- (int)legs {
  return 4;
}
@end

@interface Bird : Animal
@end

@implementation Bird
@end

@interface Animal (Loud)
+ (int)noise;
@end

@implementation Animal (Loud)
+ (int)noise {
  return 2;
}
@end

@interface Bird (Legs)
- (int)legs;
@end

@implementation Bird (Legs)
- (int)legs {
  return 2;
}
@end

test_main(0) {
  test_assert([Animal noise] == 2);
  test_assert([Bird noise] == 2);

  Animal *animal = [[Animal alloc] init];
  Bird *bird = [[Bird alloc] init];
  test_assert([animal legs] == 4);
  test_assert([bird legs] == 2);
  [bird free];
  [animal free];
}
