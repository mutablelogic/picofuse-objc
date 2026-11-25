#include <test/TestString.h>
#include <test/test.h>

test_main(0) {
  TestString *a = @"apple";
  TestString *same = @"apple";
  TestString *longer = @"apples";
  TestString *other = @"grape";

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
  test_assert_strequal(object_getClassName(a), "TestString");
}
