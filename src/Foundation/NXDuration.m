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

// TODO: This needs NXString
#if 0
NXString *NXDurationDescription(NXDuration duration, NXDuration truncate) {
  // The magnitude is unsigned, as the most negative duration has no positive
  // equivalent
  uint64_t value = duration < 0 ? -(uint64_t)duration : (uint64_t)duration;
  if (truncate > 0) {
    value -= value % (uint64_t)truncate;
  }
  if (value == 0) {
    return [NXString stringWithCString:"0s"];
  }

  // Create a string with capacity for the maximum possible length
  NXString *desc = [NXString stringWithCapacity:64];
  if (duration < 0) {
    [desc appendCString:"-"];
  }

  // Each of these fits into a long, which is 32 bits on a Pico
  long days = (long)(value / NXDay);
  value %= NXDay;
  if (days > 0) {
    [desc appendStringWithFormat:@"%ld day%s ", days, (days == 1) ? "" : "s"];
  }
  long hours = (long)(value / NXHour);
  value %= NXHour;
  if (hours > 0) {
    [desc appendStringWithFormat:@"%ldh ", hours];
  }
  long minutes = (long)(value / NXMinute);
  value %= NXMinute;
  if (minutes > 0) {
    [desc appendStringWithFormat:@"%ldm ", minutes];
  }
  long seconds = (long)(value / NXSecond);
  value %= NXSecond;
  if (seconds > 0) {
    [desc appendStringWithFormat:@"%lds ", seconds];
  }
  long milliseconds = (long)(value / NXMillisecond);
  if (milliseconds > 0) {
    [desc appendStringWithFormat:@"%ldms ", milliseconds];
  }

  // Return the formatted string, trimming any trailing spaces
  [desc trimWhitespace];
  return desc;
}
#endif
