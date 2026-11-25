#include <test/TestString.h>
#include <test/test.h>

test_main(0) {
  TestString *hello = @"Hello, world!";
  sys_printf("%s\n", [hello cStr]);
  test_assert([hello length] == 13);
}
