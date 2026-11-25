#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

uint32_t NXDurationMilliseconds(NXDuration duration) {
  if (duration <= 0) {
    return 0;
  }
  int64_t ms = duration / NXMillisecond;
  if (duration % NXMillisecond != 0) {
    ms++;
  }
  return ms > UINT32_MAX ? UINT32_MAX : (uint32_t)ms;
}

NXDuration NXDurationTimestamp(void) {
  return (NXDuration)sys_timestamp_ms() * NXMillisecond;
}

NXString *NXDurationDescription(NXDuration duration, NXDuration truncate) {
  static const struct {
    NXDuration unit;
    const char *name, *plural;
  } units[] = {
      {NXDay, " day", " days"},     {NXHour, "h", "h"},
      {NXMinute, "m", "m"},         {NXSecond, "s", "s"},
      {NXMillisecond, "ms", "ms"},  {NXMicrosecond, "us", "us"},
      {NXNanosecond, "ns", "ns"},
  };

  // The magnitude is unsigned, as the most negative duration has no positive
  // equivalent
  uint64_t value = duration < 0 ? -(uint64_t)duration : (uint64_t)duration;
  if (truncate > 0) {
    value -= value % (uint64_t)truncate;
  }
  if (value == 0) {
    return @"0s";
  }

  NXMutableString *description = [NXMutableString stringWithCapacity:48];
  if (duration < 0 && ![description appendCString:"-"]) {
    return nil;
  }
  const char *separator = "";
  for (size_t i = 0; i < sizeof(units) / sizeof(units[0]); i++) {
    uint64_t count = value / (uint64_t)units[i].unit;
    value %= (uint64_t)units[i].unit;
    if (count > 0) {
      if (![description
              appendFormat:@"%s%lu%s", separator, count,
                           count == 1 ? units[i].name : units[i].plural]) {
        return nil;
      }
      separator = " ";
    }
  }
  return description;
}
