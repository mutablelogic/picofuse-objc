#include <Foundation/Foundation.h>
#include <test/test.h>

// The units can be used where a constant is needed
static const NXDuration timeout = NXMinute + 30 * NXSecond;
_Static_assert(NXDay == 86400 * NXSecond, "NXDay");

test_main(0) {
  // Units
  test_assert(sizeof(NXDuration) == 8);
  test_assert(NXMicrosecond == 1000 * NXNanosecond);
  test_assert(NXMillisecond == 1000000 * NXNanosecond);
  test_assert(NXSecond == 1000000000 * NXNanosecond);
  test_assert(NXHour == 3600 * NXSecond);
  test_assert(timeout == 90 * NXSecond);
  test_assert(365 * 290 * NXDay > 0 && -365 * 290 * NXDay < 0);
  switch (timeout / NXSecond) {
  case 90 * NXSecond / NXSecond:
    break;
  default:
    test_assert(NO);
  }

  // Division and the remainder are exact
  test_assert((7 * NXSecond) / (2 * NXSecond) == 3);
  test_assert((7 * NXSecond) % (2 * NXSecond) == NXSecond);

  // Milliseconds are rounded up, and limited
  test_assert(NXDurationMilliseconds(0) == 0);
  test_assert(NXDurationMilliseconds(-1) == 0);
  test_assert(NXDurationMilliseconds(INT64_MIN) == 0);
  test_assert(NXDurationMilliseconds(NXNanosecond) == 1);
  test_assert(NXDurationMilliseconds(NXMillisecond) == 1);
  test_assert(NXDurationMilliseconds(NXMillisecond + 1) == 2);
  test_assert(NXDurationMilliseconds(timeout) == 90000);
  test_assert(NXDurationMilliseconds(UINT32_MAX * NXMillisecond) == UINT32_MAX);
  test_assert(NXDurationMilliseconds(UINT32_MAX * NXMillisecond - 1) ==
              UINT32_MAX);
  test_assert(NXDurationMilliseconds(UINT32_MAX * NXMillisecond + 1) ==
              UINT32_MAX);
  test_assert(NXDurationMilliseconds(INT64_MAX) == UINT32_MAX);

  // Timestamps increase with time
  NXDuration start = NXDurationTimestamp();
  test_assert(start >= 0);
  sys_sleep_ms(NXDurationMilliseconds(50 * NXMillisecond));
  NXDuration elapsed = NXDurationTimestamp() - start;
  test_assert(elapsed >= 45 * NXMillisecond && elapsed < 5 * NXSecond);
}
