/**
 * @file NXDate.h
 * @brief Defines the NXDate class, for dates and times.
 */
#pragma once
#include "NXComparisonResult.h"
#include "NXDuration.h"
#include <picofuse/sys.h>
#include <stdint.h>

/**
 * @brief Ways of writing a date.
 * @ingroup Foundation
 *
 * \headerfile NXDate.h Foundation/Foundation.h
 */
typedef enum {
  NXDateFormatISO8601 = sys_date_format_iso8601, ///< "2026-09-06T11:37:05Z", or with
                                                 ///< an offset such as "+01:00"
  NXDateFormatRFC2822 = sys_date_format_rfc2822, ///< "Sun, 06 Sep 2026 11:37:05 GMT",
                                                 ///< as in HTTP, always in UTC
  NXDateFormatLog = sys_date_format_log,         ///< "2026-09-06 11:37:05", always
                                                 ///< in UTC
} NXDateFormat;

/**
 * @brief A date and time, to the nanosecond, with the offset of a time zone.
 * @ingroup Foundation
 *
 * A date is a sys_date_t of picofuse, and can't be changed once it's made. Its parts, and
 * how it's written, are only available for the years 0 to 65535.
 *
 * The time zone only changes how a date is written, and its local parts: two dates at
 * the same moment are equal, whatever their time zones. The current date has the time
 * zone of the system; others are in UTC unless they're given one.
 *
 * On a Pico, the clock starts at 1970-01-01 when it's turned on, until it's set, and is
 * to the millisecond.
 *
 * \headerfile NXDate.h Foundation/Foundation.h
 */
@interface NXDate : NXObject {
@private
  sys_date_t _date;
}

/**
 * @brief Returns the current date, or nil if the clock can't be read.
 */
+ (id)date;

/**
 * @brief Returns the current date with a duration added, which is earlier if it's
 * negative.
 */
+ (id)dateWithDuration:(NXDuration)duration;

/**
 * @brief Returns a date from the number of seconds since 1970-01-01 in UTC.
 * @param seconds The seconds, which are negative before 1970.
 * @param nanoseconds The nanoseconds after that. Any more than a second, or fewer than
 * zero, are carried into the seconds.
 * @return The date, or nil if the seconds would overflow.
 */
+ (id)dateWithSeconds:(int64_t)seconds nanoseconds:(int32_t)nanoseconds;

/**
 * @brief Returns a date at midnight in UTC, or nil if it doesn't exist.
 * @param year The year, from 1900 to 65535.
 * @param month The month, from 1 to 12.
 * @param day The day of the month, from 1.
 */
+ (id)dateWithYear:(uint16_t)year month:(uint8_t)month day:(uint8_t)day;

/**
 * @brief Returns a date and time in UTC, or nil if it doesn't exist.
 * @param hours From 0 to 23.
 * @param minutes From 0 to 59.
 * @param seconds From 0 to 59.
 */
+ (id)dateWithYear:(uint16_t)year
             month:(uint8_t)month
               day:(uint8_t)day
             hours:(uint8_t)hours
           minutes:(uint8_t)minutes
           seconds:(uint8_t)seconds;

/**
 * @brief Returns a date read from a string in a format.
 * @param string The whole of it is a date in the format:
 * - NXDateFormatISO8601: "2026-09-06T11:37:05Z", with an optional fraction of a second,
 *   and "Z" or an offset such as "+01:00". Or just a date, "2026-09-06", which is
 *   midnight UTC.
 * - NXDateFormatRFC2822: "Sun, 06 Sep 2026 11:37:05 GMT", where the weekday is optional
 *   but must be right, and the zone can be "GMT", "UTC" or an offset such as "+0100".
 * - NXDateFormatLog: "2026-09-06 11:37:05", in UTC.
 * @return The date, in the time zone it was written in, or nil if it isn't a date in the
 * format or doesn't exist.
 */
+ (id)dateWithString:(NXString *)string format:(NXDateFormat)format;

/**
 * @brief Returns a date read from a string in any of the formats, which are tried in turn,
 * or nil if it isn't one.
 */
+ (id)dateWithString:(NXString *)string;

/**
 * @brief Sets the clock of the system.
 * @return YES if it was set. On a Mac or Linux, that needs permission.
 *
 * On a Pico, the time zone of the date becomes that of the system.
 */
+ (BOOL)setCurrentDate:(NXDate *)date;

/**
 * @brief Initializes the current date.
 */
- (id)init;

/**
 * @brief Initializes a date from the number of seconds since 1970-01-01 in UTC.
 */
- (id)initWithSeconds:(int64_t)seconds nanoseconds:(int32_t)nanoseconds;

/**
 * @brief Initializes a date and time in UTC.
 */
- (id)initWithYear:(uint16_t)year
             month:(uint8_t)month
               day:(uint8_t)day
             hours:(uint8_t)hours
           minutes:(uint8_t)minutes
           seconds:(uint8_t)seconds;

/**
 * @brief Initializes a date read from a string in a format.
 */
- (id)initWithString:(NXString *)string format:(NXDateFormat)format;

/**
 * @brief Returns the number of whole seconds since 1970-01-01 in UTC, which is negative
 * before then.
 */
- (int64_t)seconds;

/**
 * @brief Returns the nanoseconds after the seconds, from zero to 999999999.
 */
- (int32_t)nanoseconds;

/**
 * @brief Returns the offset of the time zone, in seconds east of UTC.
 */
- (int32_t)timeZoneOffset;

/**
 * @brief Returns the same moment in another time zone.
 * @param offset The offset, in seconds east of UTC. It's written in ISO 8601 to the
 * minute.
 */
- (NXDate *)dateWithTimeZoneOffset:(int32_t)offset;

/**
 * @brief Returns this date with a duration added, which is earlier if it's negative.
 * @return The date, in the same time zone, or nil if its seconds would overflow.
 */
- (NXDate *)dateByAddingDuration:(NXDuration)duration;

/**
 * @brief Returns the time since another date, which is negative if that's later.
 * @param other The other date, or nil for the current date.
 * @return The duration. Durations can be up to about 292 years, and it's the longest
 * duration, positive or negative, if the dates are further apart.
 */
- (NXDuration)durationSinceDate:(NXDate *)other;

/**
 * @brief Compares the moments of two dates. If the other is nil, it's the current
 * date.
 * @return NXComparisonAscending if this is earlier, NXComparisonSame if they're at the
 * same moment, or NXComparisonDescending if this is later.
 */
- (NXComparisonResult)compare:(NXDate *)other;

/**
 * @brief Returns YES if another object is a date at the same moment.
 */
- (BOOL)isEqual:(id)anObject;

/**
 * @brief Returns a hash of the moment, which is the same for equal dates, whatever their
 * time zones.
 */
- (uintptr_t)hash;

/**
 * @brief Gets the date in UTC. Any of the arguments can be NULL.
 * @param weekday The day of the week, from 0 for Sunday to 6.
 * @return YES if successful, or NO if the year isn't from 0 to 65535.
 */
- (BOOL)year:(uint16_t *)year
       month:(uint8_t *)month
         day:(uint8_t *)day
     weekday:(uint8_t *)weekday;

/**
 * @brief Gets the time in UTC. Any of the arguments can be NULL.
 * @return YES if successful, or NO if the year isn't from 0 to 65535.
 */
- (BOOL)hours:(uint8_t *)hours minutes:(uint8_t *)minutes seconds:(uint8_t *)seconds;

/**
 * @brief Gets the date in the date's time zone. Any of the arguments can be NULL.
 * @return YES if successful, or NO if the year isn't from 0 to 65535.
 */
- (BOOL)localYear:(uint16_t *)year
            month:(uint8_t *)month
              day:(uint8_t *)day
          weekday:(uint8_t *)weekday;

/**
 * @brief Gets the time in the date's time zone. Any of the arguments can be NULL.
 * @return YES if successful, or NO if the year isn't from 0 to 65535.
 */
- (BOOL)localHours:(uint8_t *)hours
           minutes:(uint8_t *)minutes
           seconds:(uint8_t *)seconds;

/**
 * @brief Returns the date written in a format, or nil if the year isn't from 0 to 65535
 * or there isn't enough memory.
 */
- (NXString *)stringWithFormat:(NXDateFormat)format;

/**
 * @brief Returns the date in ISO 8601, such as "2026-09-06T11:37:05Z", or nil if the year
 * isn't from 0 to 65535.
 */
- (NXString *)description;

@end
