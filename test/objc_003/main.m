#include <test/test.h>

test_main(0) {
  NXConstantString *a = @"apple";
  NXConstantString *same = @"apple";
  NXConstantString *longer = @"apples";
  NXConstantString *other = @"grape";

  test_assert([a length] == 5);
  test_assert([longer length] == 6);
  test_assert([@"" length] == 0);
  test_assert_strequal([a cStr], "apple");
  test_assert_strequal([longer cStr], "apples");

  test_assert([a isEqual:a]);
  test_assert([a isEqual:same]);
  test_assert(![a isEqual:longer]);
  test_assert(![a isEqual:other]);
  test_assert(![a isEqual:nil]);
  test_assert_strequal(object_getClassName(a), "NXConstantString");
}
