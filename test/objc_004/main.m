#include <test/TestObject.h>
#include <test/test.h>

@interface Thing : TestObject
+ (id)echo:(id)value;
@end

@implementation Thing
+ (id)echo:(id)value {
  return value;
}
@end

test_main(0) {
  TestObject *object = [[TestObject alloc] init];
  Thing *thing = [[Thing alloc] init];
  test_assert(object != nil && thing != nil);

  test_assert_strequal(object_getClassName(object), "TestObject");
  test_assert_strequal(object_getClassName(thing), "Thing");
  test_assert_strequal(class_getName(object_getClass(thing)), "Thing");
  test_assert_strequal([Thing name], "Thing");

  test_assert([thing class] == [Thing class]);
  test_assert([thing class] != [object class]);
  test_assert([thing superclass] == [TestObject class]);
  test_assert([thing isKindOfClass:[Thing class]]);
  test_assert([thing isKindOfClass:[Object class]]);
  test_assert(![object isKindOfClass:[Thing class]]);

  test_assert([thing isEqual:thing]);
  test_assert(![thing isEqual:object]);
  test_assert([Thing echo:thing] == thing);

  Thing *none = nil;
  test_assert([none class] == Nil);
  test_assert(![none isEqual:thing]);

  [thing free];
  [object free];
}
