#include <Foundation/Foundation.h>
#include <test/test.h>

// 2026-09-06T11:37:05Z, a Sunday
#define SAMPLE INT64_C(1788694625)

// 65535-12-31T23:59:59Z, the last which can be written
#define LAST INT64_C(2005949145599)

static void check(NXDate *date, NXDateFormat format, const char *expected) {
  test_assert(date != nil);
  test_assert_strequal([[date stringWithFormat:format] cStr], expected);
}

static void dates(NXZone *zone) {
  // From seconds
  NXDate *date = [NXDate dateWithSeconds:0 nanoseconds:0];
  test_assert([date zone] == zone);
  check(date, NXDateFormatISO8601, "1970-01-01T00:00:00Z");
  test_assert([date seconds] == 0 && [date nanoseconds] == 0);
  test_assert([date timeZoneOffset] == 0);
  uint16_t year = 0;
  uint8_t month = 0, day = 0, weekday = 9, hours = 99, minutes = 99, seconds = 99;
  test_assert([date year:&year month:&month day:&day weekday:&weekday]);
  test_assert(year == 1970 && month == 1 && day == 1 && weekday == 4);

  date = [NXDate dateWithSeconds:SAMPLE nanoseconds:123456789];
  check(date, NXDateFormatISO8601, "2026-09-06T11:37:05Z");
  check(date, NXDateFormatRFC2822, "Sun, 06 Sep 2026 11:37:05 GMT");
  check(date, NXDateFormatLog, "2026-09-06 11:37:05");
  test_assert_strequal([[date description] cStr], "2026-09-06T11:37:05Z");
  test_assert([date nanoseconds] == 123456789);
  test_assert([date hours:&hours minutes:&minutes seconds:&seconds]);
  test_assert(hours == 11 && minutes == 37 && seconds == 5);
  test_assert([date year:NULL month:NULL day:NULL weekday:&weekday] && weekday == 0);
  test_assert([date hours:NULL minutes:NULL seconds:NULL]);

  // Nanoseconds are carried into the seconds
  date = [NXDate dateWithSeconds:SAMPLE nanoseconds:-1];
  test_assert([date seconds] == SAMPLE - 1 && [date nanoseconds] == 999999999);
  date = [NXDate dateWithSeconds:SAMPLE nanoseconds:2000000001];
  test_assert([date seconds] == SAMPLE + 2 && [date nanoseconds] == 1);
  test_assert([NXDate dateWithSeconds:INT64_MAX nanoseconds:1000000000] == nil);
  test_assert([NXDate dateWithSeconds:INT64_MIN nanoseconds:-1] == nil);

  // From parts, in UTC
  date = [NXDate dateWithYear:2026 month:9 day:6 hours:11 minutes:37 seconds:5];
  test_assert([date seconds] == SAMPLE && [date nanoseconds] == 0);
  date = [NXDate dateWithYear:2000 month:2 day:29];
  check(date, NXDateFormatISO8601, "2000-02-29T00:00:00Z");
  test_assert([date year:NULL month:NULL day:NULL weekday:&weekday] && weekday == 2);
  test_assert([NXDate dateWithYear:2001 month:2 day:29] == nil);
  test_assert([NXDate dateWithYear:2026 month:13 day:1] == nil);
  test_assert([NXDate dateWithYear:2026 month:0 day:1] == nil);
  test_assert([NXDate dateWithYear:2026 month:4 day:31] == nil);
  test_assert([NXDate dateWithYear:1899 month:12 day:31] == nil);
  test_assert([NXDate dateWithYear:1900 month:1 day:1] != nil);
  test_assert([NXDate dateWithYear:2026 month:1 day:1 hours:24 minutes:0 seconds:0] ==
              nil);
  test_assert([NXDate dateWithYear:2026 month:1 day:1 hours:0 minutes:60 seconds:0] ==
              nil);
  test_assert([NXDate dateWithYear:2026 month:1 day:1 hours:0 minutes:0 seconds:60] ==
              nil);

  // Time zones change the local parts and how it's written, not the moment
  date = [NXDate dateWithSeconds:SAMPLE nanoseconds:0];
  NXDate *local = [date dateWithTimeZoneOffset:3600];
  test_assert([local zone] == zone && [local timeZoneOffset] == 3600);
  check(local, NXDateFormatISO8601, "2026-09-06T12:37:05+01:00");
  check(local, NXDateFormatLog, "2026-09-06 12:37:05");
  check(local, NXDateFormatRFC2822, "Sun, 06 Sep 2026 11:37:05 GMT");
  test_assert([local localHours:&hours minutes:&minutes seconds:&seconds]);
  test_assert(hours == 12 && minutes == 37 && seconds == 5);
  test_assert([local hours:&hours minutes:NULL seconds:NULL] && hours == 11);
  test_assert([local isEqual:date] && [date isEqual:local]);
  test_assert([local compare:date] == NXComparisonSame);
  check([date dateWithTimeZoneOffset:-(5 * 3600 + 30 * 60)], NXDateFormatISO8601,
        "2026-09-06T06:07:05-05:30");

  // The largest offsets can be written
  date = [NXDate dateWithSeconds:0 nanoseconds:0];
  check([date dateWithTimeZoneOffset:INT32_MIN], NXDateFormatISO8601,
        "1901-12-13T20:45:52-596523:14");
  check([date dateWithTimeZoneOffset:INT32_MAX], NXDateFormatISO8601,
        "2038-01-19T03:14:07+596523:14");

  // The local day can be another
  date = [[NXDate dateWithYear:2026 month:1 day:1 hours:0 minutes:30 seconds:0]
      dateWithTimeZoneOffset:-3600];
  test_assert([date localYear:&year month:&month day:&day weekday:&weekday]);
  test_assert(year == 2025 && month == 12 && day == 31 && weekday == 3);
  test_assert([date year:&year month:&month day:&day weekday:&weekday]);
  test_assert(year == 2026 && month == 1 && day == 1 && weekday == 4);

  // Adding durations, which keeps the time zone
  date = [[NXDate dateWithSeconds:10 nanoseconds:200000000] dateWithTimeZoneOffset:60];
  NXDate *later = [date dateByAddingDuration:1500 * NXMillisecond];
  test_assert([later zone] == zone);
  test_assert([later seconds] == 11 && [later nanoseconds] == 700000000);
  test_assert([later timeZoneOffset] == 60);
  NXDate *earlier = [date dateByAddingDuration:-300 * NXMillisecond];
  test_assert([earlier seconds] == 9 && [earlier nanoseconds] == 900000000);
  test_assert([[date dateByAddingDuration:0] isEqual:date]);
  test_assert([[NXDate dateWithSeconds:INT64_MAX nanoseconds:999999999]
                  dateByAddingDuration:1] == nil);

  // The time between them
  test_assert([later durationSinceDate:date] == 1500 * NXMillisecond);
  test_assert([earlier durationSinceDate:later] == -1800 * NXMillisecond);
  test_assert([date durationSinceDate:date] == 0);
  NXDate *first = [NXDate dateWithYear:1900 month:1 day:1];
  NXDate *last = [NXDate dateWithYear:9999 month:12 day:31];
  test_assert([last durationSinceDate:first] == INT64_MAX);
  test_assert([first durationSinceDate:last] == INT64_MIN);

  // The longest which fit, where the nanoseconds take it back into range
  NXDate *fraction = [NXDate dateWithSeconds:0 nanoseconds:999999999];
  NXDate *far = [NXDate dateWithSeconds:9223372037 nanoseconds:0];
  test_assert([far durationSinceDate:fraction] == INT64_C(9223372036000000001));
  test_assert([fraction durationSinceDate:far] == -INT64_C(9223372036000000001));

  // Comparing
  test_assert([earlier compare:date] == NXComparisonAscending);
  test_assert([later compare:date] == NXComparisonDescending);
  test_assert([[NXDate dateWithSeconds:10 nanoseconds:1] compare:
                   [NXDate dateWithSeconds:10 nanoseconds:2]] == NXComparisonAscending);
  test_assert([[NXDate dateWithSeconds:-1 nanoseconds:999999999] compare:
                   [NXDate dateWithSeconds:0 nanoseconds:0]] == NXComparisonAscending);
  test_assert(![date isEqual:later] && ![date isEqual:nil]);
  test_assert(![date isEqual:@"1970-01-01T00:00:10Z"]);
  test_assert([date isEqual:date]);

  // In a format
  NXString *string = [NXString stringWithFormat:@"at %@", first];
  test_assert_strequal([string cStr], "at 1900-01-01T00:00:00Z");

  // Years which can't be written
  date = [NXDate dateWithSeconds:LAST nanoseconds:0];
  check(date, NXDateFormatISO8601, "65535-12-31T23:59:59Z");
  date = [date dateByAddingDuration:NXSecond];
  test_assert(date != nil && [date description] == nil);
  test_assert([date stringWithFormat:NXDateFormatRFC2822] == nil);
  test_assert(![date year:&year month:NULL day:NULL weekday:NULL]);
  test_assert(![date hours:&hours minutes:NULL seconds:NULL]);
  date = [[NXDate dateWithSeconds:LAST nanoseconds:0] dateWithTimeZoneOffset:1];
  test_assert(![date localYear:&year month:NULL day:NULL weekday:NULL]);
  test_assert(![date localHours:&hours minutes:NULL seconds:NULL]);
  test_assert([date year:&year month:NULL day:NULL weekday:NULL] && year == 65535);

  // Now
  NXDate *now = [NXDate date];
  test_assert(now != nil && [now zone] == zone);
  NXDate *initialized = [[[NXDate alloc] init] autorelease];
  test_assert([initialized compare:now] != NXComparisonAscending);
  NXDate *hour = [NXDate dateWithDuration:NXHour];
  NXDuration since = [hour durationSinceDate:now];
  test_assert(since >= NXHour && since < NXHour + NXSecond);
  since = [hour durationSinceDate:nil];
  test_assert(since > NXHour - NXSecond && since <= NXHour);
  test_assert([NXDate setCurrentDate:nil] == NO);
}

test_main(0) {
  for (int i = 0; i < 3; i++) {
    NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
    dates(nil);
    [pool release];
  }

  NXZone *zone = [NXZone zoneWithSize:8192];
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  dates(zone);
  [pool release];
  test_assert([zone count] == 0);
  [zone release];

#ifdef SYSTEM_NAME_PICO
  // Setting the clock, which only a Pico can do without permission
  pool = [[NXAutoreleasePool alloc] init];
  NXDate *date = [NXDate dateWithYear:2026 month:9 day:6 hours:11 minutes:37 seconds:5];
  test_assert([NXDate setCurrentDate:date]);
  NXDuration since = [[NXDate date] durationSinceDate:date];
  test_assert(since >= 0 && since < NXSecond);
  test_assert([[NXDate date] timeZoneOffset] == 0);
  test_assert([NXDate setCurrentDate:[date dateWithTimeZoneOffset:3600]]);
  test_assert([[NXDate date] timeZoneOffset] == 3600);
  [pool release];
#endif
}
