#include <Foundation/Foundation.h>
#include <test/test.h>

@interface Plain : NXObject
@end
@implementation Plain
@end

@interface Described : Plain
@end
@implementation Described
- (NXString *)description {
  return [NXString stringWithFormat:@"[%@ %@]", [super description],
                                    [NXNumber numberWithBool:YES]];
}
@end

static void check(id object, const char *expected) {
  test_assert_strequal([[object description] cStr], expected);
  NXString *formatted = [NXString stringWithFormat:@"%@", object];
  test_assert_strequal([formatted cStr], expected);
}

static void check_duration(NXDuration duration, NXDuration truncate,
                           const char *expected) {
  test_assert_strequal([NXDurationDescription(duration, truncate) cStr],
                       expected);
}

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];

  // Objects and classes
  check([[[Plain alloc] init] autorelease], "Plain");
  check([[[Described alloc] init] autorelease], "[Described true]");
  check((id)[Plain class], "Plain");
  check(pool, "NXAutoreleasePool");
  check(@"a string", "a string");
  check([NXMutableString stringWithCString:"mutable"], "mutable");
  check([NXNull nullValue], "null");

  // Numbers
  check([NXNumber zeroValue], "0");
  check([NXNumber trueValue], "true");
  check([NXNumber falseValue], "false");
  check([NXNumber numberWithInt16:INT16_MIN], "-32768");
  check([NXNumber numberWithUnsignedInt16:UINT16_MAX], "65535");
  check([NXNumber numberWithInt32:INT32_MIN], "-2147483648");
  check([NXNumber numberWithUnsignedInt32:UINT32_MAX], "4294967295");
  check([NXNumber numberWithInt64:INT64_MIN], "-9223372036854775808");
  check([NXNumber numberWithInt64:INT64_MAX], "9223372036854775807");
  check([NXNumber numberWithUnsignedInt64:UINT64_MAX], "18446744073709551615");
  check([NXNumber numberWithFloat32:0.1f], "0.1");
  check([NXNumber numberWithFloat32:-2.5f], "-2.5");
  check([NXNumber numberWithFloat64:0.1], "0.1");
  check([NXNumber numberWithFloat64:3.14159265], "3.14159265");
  check([NXNumber numberWithFloat64:1e100], "1e+100");
  check([NXNumber numberWithFloat64:__builtin_inf()], "inf");
  check([NXNumber numberWithFloat64:__builtin_nan("")], "nan");

  // Durations
  check_duration(0, 0, "0s");
  check_duration(NXSecond, 0, "1s");
  check_duration(NXDay, 0, "1 day");
  check_duration(2 * NXDay + NXHour, 0, "2 days 1h");
  check_duration(NXDay + 2 * NXHour + 3 * NXMinute + 4 * NXSecond +
                     5 * NXMillisecond + 6 * NXMicrosecond + 7,
                 0, "1 day 2h 3m 4s 5ms 6us 7ns");
  check_duration(-90 * NXSecond, 0, "-1m 30s");
  check_duration(500 * NXMicrosecond, 0, "500us");
  check_duration(500 * NXMicrosecond, NXMillisecond, "0s");
  check_duration(1500 * NXMillisecond, NXSecond, "1s");
  check_duration(-1500 * NXMillisecond, NXSecond, "-1s");
  check_duration(INT64_MAX, NXDay, "106751 days");
  check_duration(INT64_MIN, 0, "-106751 days 23h 47m 16s 854ms 775us 808ns");

  [pool release];
}
