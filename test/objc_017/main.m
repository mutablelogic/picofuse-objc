#include <test/test.h>

@protocol One
- (void)one;
@end

@protocol Two
- (void)two;
@end

test_main(0) {
  Protocol *one = @protocol(One);
  Protocol *two = @protocol(Two);
  test_assert(one != nil && two != nil && one != two);

  test_assert_strequal(proto_getName((objc_protocol_t *)one), "One");
  test_assert_strequal(proto_getName((objc_protocol_t *)two), "Two");
  test_assert(proto_getName(NULL) == NULL);
  test_assert_strequal([one name], "One");
  test_assert_strequal([Protocol name], "Protocol");

  test_assert([one isEqual:one]);
  test_assert([one isEqual:@protocol(One)]);
  test_assert(![one isEqual:two]);
  test_assert(![one isEqual:nil]);
  test_assert([one conformsTo:one]);
  test_assert(![one conformsTo:two]);
}
