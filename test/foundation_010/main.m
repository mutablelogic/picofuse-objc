#include <Foundation/Foundation.h>
#include <test/test.h>

// Each of these panics, when it's returned as an integer
#if defined(CASE_nan)
#define VALUE __builtin_nan("")
#elif defined(CASE_inf)
#define VALUE __builtin_inf()
#elif defined(CASE_minus_inf)
#define VALUE (-__builtin_inf())
#elif defined(CASE_limit)
#define VALUE 18446744073709551616.0 // Two to the power of 64
#elif defined(CASE_minus_limit)
#define VALUE (-18446744073709551616.0)
#endif

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  NXNumber *number = [NXNumber numberWithFloat64:VALUE];
  test_assert([number float64Value] == VALUE || VALUE != VALUE);
  sys_printf("%d\n", (int)([number unsignedInt64Value] & 1));
  [pool release];
}
