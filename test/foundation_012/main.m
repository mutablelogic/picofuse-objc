#include <Foundation/Foundation.h>
#include <test/test.h>

test_main(0) {
  sys_printf("%s\n", [@"Hello, world!" cStr]);
  test_assert([@"Hello, world!" length] == 13);
}
