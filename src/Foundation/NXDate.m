#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

// The most bytes of a date which is written
#define STRING_SIZE 48

///////////////////////////////////////////////////////////////////////////////
// PRIVATE METHODS

@interface NXDate (Private)
- (id)initWithDate:(const sys_date_t *)date;
@end

@implementation NXDate

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

+ (id)date {
  return [[[self alloc] init] autorelease];
}

+ (id)dateWithDuration:(NXDuration)duration {
  return [[self date] dateByAddingDuration:duration];
}

+ (id)dateWithSeconds:(int64_t)seconds nanoseconds:(int32_t)nanoseconds {
  return [[[self alloc] initWithSeconds:seconds nanoseconds:nanoseconds]
      autorelease];
}

+ (id)dateWithYear:(uint16_t)year month:(uint8_t)month day:(uint8_t)day {
  return [self dateWithYear:year month:month day:day hours:0 minutes:0 seconds:0];
}

+ (id)dateWithYear:(uint16_t)year
             month:(uint8_t)month
               day:(uint8_t)day
             hours:(uint8_t)hours
           minutes:(uint8_t)minutes
           seconds:(uint8_t)seconds {
  return [[[self alloc] initWithYear:year
                               month:month
                                 day:day
                               hours:hours
                             minutes:minutes
                             seconds:seconds] autorelease];
}

+ (BOOL)setCurrentDate:(NXDate *)date {
  return date != nil && sys_date_set_now(&date->_date);
}

- (id)init {
  sys_date_t date;
  if (!sys_date_get_now(&date)) {
    [self release];
    return nil;
  }
  return [self initWithDate:&date];
}

- (id)initWithSeconds:(int64_t)seconds nanoseconds:(int32_t)nanoseconds {
  sys_date_t date = {.seconds = seconds};
  if (!sys_date_add_ns(&date, nanoseconds)) {
    [self release];
    return nil;
  }
  return [self initWithDate:&date];
}

- (id)initWithYear:(uint16_t)year
             month:(uint8_t)month
               day:(uint8_t)day
             hours:(uint8_t)hours
           minutes:(uint8_t)minutes
           seconds:(uint8_t)seconds {
  // picofuse checks that they're in range, and that the day exists
  sys_date_t date = {0};
  if (!sys_date_set_date_utc(&date, year, month, day) ||
      !sys_date_set_time_utc(&date, hours, minutes, seconds)) {
    [self release];
    return nil;
  }
  return [self initWithDate:&date];
}

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

- (int64_t)seconds {
  return _date.seconds;
}

- (int32_t)nanoseconds {
  return _date.nanoseconds;
}

- (int32_t)timeZoneOffset {
  return _date.tzoffset;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

- (NXDate *)dateWithTimeZoneOffset:(int32_t)offset {
  sys_date_t date = _date;
  date.tzoffset = offset;
  return [[[NXDate allocWithZone:[self zone]] initWithDate:&date] autorelease];
}

- (NXDate *)dateByAddingDuration:(NXDuration)duration {
  sys_date_t date = _date;
  if (!sys_date_add_ns(&date, duration)) {
    return nil;
  }
  return [[[NXDate allocWithZone:[self zone]] initWithDate:&date] autorelease];
}

- (NXDuration)durationSinceDate:(NXDate *)other {
  return sys_date_compare_ns(other == nil ? NULL : &other->_date, &_date);
}

- (NXComparisonResult)compare:(NXDate *)other {
  if (_date.seconds != other->_date.seconds) {
    return _date.seconds < other->_date.seconds ? NXComparisonAscending
                                                 : NXComparisonDescending;
  }
  if (_date.nanoseconds != other->_date.nanoseconds) {
    return _date.nanoseconds < other->_date.nanoseconds ? NXComparisonAscending
                                                         : NXComparisonDescending;
  }
  return NXComparisonSame;
}

- (BOOL)isEqual:(id)anObject {
  if (anObject == self) {
    return YES;
  }
  return anObject != nil && object_isKindOfClass(anObject, [NXDate class]) &&
         [self compare:anObject] == NXComparisonSame;
}

- (BOOL)year:(uint16_t *)year
       month:(uint8_t *)month
         day:(uint8_t *)day
     weekday:(uint8_t *)weekday {
  return sys_date_get_date_utc(&_date, year, month, day, weekday);
}

- (BOOL)hours:(uint8_t *)hours minutes:(uint8_t *)minutes seconds:(uint8_t *)seconds {
  return sys_date_get_time_utc(&_date, hours, minutes, seconds);
}

- (BOOL)localYear:(uint16_t *)year
            month:(uint8_t *)month
              day:(uint8_t *)day
          weekday:(uint8_t *)weekday {
  return sys_date_get_date_local(&_date, year, month, day, weekday);
}

- (BOOL)localHours:(uint8_t *)hours
           minutes:(uint8_t *)minutes
           seconds:(uint8_t *)seconds {
  return sys_date_get_time_local(&_date, hours, minutes, seconds);
}

- (NXString *)stringWithFormat:(NXDateFormat)format {
  char buffer[STRING_SIZE];
  size_t length =
      sys_date_to_string(&_date, (sys_date_format_t)format, buffer, sizeof(buffer));
  if (length == 0 || length >= sizeof(buffer)) {
    return nil;
  }
  return [NXString stringWithCString:buffer];
}

- (NXString *)description {
  return [self stringWithFormat:NXDateFormatISO8601];
}

@end

@implementation NXDate (Private)

// Initializes a date from one of picofuse
- (id)initWithDate:(const sys_date_t *)date {
  self = [super init];
  if (self == nil) {
    return nil;
  }
  _date = *date;
  return self;
}

@end
