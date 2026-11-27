// Misusing a wait group panics. One case for each program.
#include <Foundation/Foundation.h>
#include <test/test.h>

test_main(0) {
  NXWaitGroup *group = [[NXWaitGroup alloc] init];
  test_assert(group != nil);
#if defined(CASE_done)
  [group add:1];
  [group done];
  [group done];
#elif defined(CASE_add)
  [group add:-1];
#endif
  test_assert(!"it should have panicked");
}
