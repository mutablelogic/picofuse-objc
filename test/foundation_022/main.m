#include <Foundation/Foundation.h>
#include <test/test.h>

// 2026-09-06T11:37:05Z, a Sunday
#define SAMPLE INT64_C(1788694625)

static NXDuration duration(const char *cStr) {
  NXDuration duration = 12345;
  test_assert(NXDurationFromString([NXString stringWithCString:cStr], &duration));
  return duration;
}

static void durations(void) {
  test_assert(duration("1h30m") == NXHour + 30 * NXMinute);
  test_assert(duration("1.5s") == 1500 * NXMillisecond);
  test_assert(duration("-250ms") == -250 * NXMillisecond);
  test_assert(duration("2d") == 2 * NXDay && duration("1day") == NXDay);
  test_assert(duration("3\xC2\xB5s") == 3 * NXMicrosecond);
  test_assert(duration("0s") == 0);

  // What's written can be read back
  NXDuration values[] = {0,
                         NXNanosecond,
                         NXDay + 2 * NXHour + 3 * NXMinute + 4 * NXSecond +
                             5 * NXMillisecond + 6 * NXMicrosecond + 7,
                         -90 * NXSecond,
                         INT64_MAX,
                         INT64_MIN};
  for (size_t i = 0; i < sizeof(values) / sizeof(values[0]); i++) {
    NXDuration read = 12345;
    test_assert(NXDurationFromString(NXDurationDescription(values[i], 0), &read));
    test_assert(read == values[i]);
  }
  NXString *string = [NXString stringWithFormat:@"%t", NXDay + 90 * NXSecond];
  test_assert_strequal([string cStr], "1d1m30s");
  NXDuration read = 0;
  test_assert(NXDurationFromString(string, &read) && read == NXDay + 90 * NXSecond);

  // Those which aren't durations, which leave it unchanged
  const char *invalid[] = {"", "1", "1 h", "1h ", "1min", "x", "106752d"};
  for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
    read = 12345;
    test_assert(!NXDurationFromString([NXString stringWithCString:invalid[i]], &read));
    test_assert(read == 12345);
  }
  test_assert(!NXDurationFromString(nil, &read) && read == 12345);
  test_assert(!NXDurationFromString(@"1s\0junk", &read) && read == 12345);
}

static void dates(NXZone *zone) {
  // Each format
  NXDate *date = [NXDate dateWithString:@"2026-09-06T11:37:05Z"
                                 format:NXDateFormatISO8601];
  test_assert([date zone] == zone);
  test_assert([date seconds] == SAMPLE && [date timeZoneOffset] == 0);
  date = [NXDate dateWithString:@"2026-09-06T12:37:05.25+01:00"
                         format:NXDateFormatISO8601];
  test_assert([date seconds] == SAMPLE && [date nanoseconds] == 250000000);
  test_assert([date timeZoneOffset] == 3600);
  test_assert_strequal([[date description] cStr], "2026-09-06T12:37:05+01:00");
  date = [NXDate dateWithString:@"Sun, 06 Sep 2026 11:37:05 GMT"
                         format:NXDateFormatRFC2822];
  test_assert([date seconds] == SAMPLE);
  date = [NXDate dateWithString:@"2026-09-06 11:37:05" format:NXDateFormatLog];
  test_assert([date seconds] == SAMPLE && [date timeZoneOffset] == 0);

  // In the wrong format, or wrong
  test_assert([NXDate dateWithString:@"2026-09-06 11:37:05"
                              format:NXDateFormatISO8601] == nil);
  test_assert([NXDate dateWithString:@"Mon, 06 Sep 2026 11:37:05 GMT"
                              format:NXDateFormatRFC2822] == nil);
  test_assert([NXDate dateWithString:@"2026-02-30" format:NXDateFormatISO8601] == nil);
  test_assert([NXDate dateWithString:nil format:NXDateFormatISO8601] == nil);
  test_assert([NXDate dateWithString:@"2026-09-06\0junk"
                              format:NXDateFormatISO8601] == nil);

  // Any format
  const char *any[] = {"2026-09-06T11:37:05Z", "Sun, 06 Sep 2026 11:37:05 GMT",
                       "06 Sep 2026 12:37:05 +0100", "2026-09-06 11:37:05"};
  for (size_t i = 0; i < sizeof(any) / sizeof(any[0]); i++) {
    date = [NXDate dateWithString:[NXString stringWithCString:any[i]]];
    test_assert(date != nil && [date seconds] == SAMPLE);
  }
  test_assert([NXDate dateWithString:@"yesterday"] == nil);
  test_assert([NXDate dateWithString:@""] == nil);

  // What's written can be read back, in every format
  NXDate *written = [[NXDate dateWithSeconds:SAMPLE nanoseconds:0]
      dateWithTimeZoneOffset:-19800];
  NXDateFormat formats[] = {NXDateFormatISO8601, NXDateFormatRFC2822, NXDateFormatLog};
  for (size_t i = 0; i < sizeof(formats) / sizeof(formats[0]); i++) {
    NXString *string = [written stringWithFormat:formats[i]];
    test_assert([[NXDate dateWithString:string format:formats[i]] isEqual:written]);
    test_assert([[NXDate dateWithString:string] isEqual:written]);
  }
}

static void scanning(void) {
  NXScanner *scanner =
      [NXScanner scannerWithString:@"at 2026-09-06T11:37:05Z wait 1h30m or 42"
                             flags:NXScannerDates | NXScannerDurations |
                                   NXScannerNumbers | NXScannerKeywords];
  int found = 0;
  while ([scanner next]) {
    NXString *token = [scanner token];
    switch ([scanner tokenClass]) {
    case NXScannerClassDate:
      test_assert([[NXDate dateWithString:token format:NXDateFormatISO8601] seconds] ==
                  SAMPLE);
      found |= 1;
      break;
    case NXScannerClassDuration: {
      NXDuration read = 0;
      test_assert(NXDurationFromString(token, &read) &&
                  read == NXHour + 30 * NXMinute);
      found |= 2;
      break;
    }
    case NXScannerClassNumber:
      test_assert([[NXNumber numberWithString:token] int64Value] == 42);
      found |= 4;
      break;
    default:
      break;
    }
  }
  test_assert(found == 7);
  test_assert(NXScannerDatesISO8601 == NXScannerDates);
}

test_main(0) {
  for (int i = 0; i < 3; i++) {
    NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
    durations();
    dates(nil);
    scanning();
    [pool release];
  }

  NXZone *zone = [NXZone zoneWithSize:8192];
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  dates(zone);
  [pool release];
  test_assert([zone count] == 0);
  [zone release];
}
