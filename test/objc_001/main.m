#include <test/test.h>

test_main(0) {
  NXConstantString *hello = @"Hello, world!";
  sys_printf("%s\n", [hello cStr]);
  test_assert([hello length] == 13);
}
