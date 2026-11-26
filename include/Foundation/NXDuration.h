/**
 * @file NXDuration.h
 * @brief Defines the NXDuration type, and constants for units of time.
 */
#pragma once
#include <stdint.h>

/**
 * @brief A length of time, in nanoseconds, which may be negative.
 * @ingroup Foundation
 *
 * Durations are made by multiplying the constants for units of time. For example,
 * `90 * NXSecond` or `NXMinute + 30 * NXSecond`. They can be up to about 292 years.
 *
 * \headerfile NXDuration.h Foundation/Foundation.h
 */
typedef int64_t NXDuration;

/** @brief One nanosecond.
 * @ingroup Foundation
 */
#define NXNanosecond ((NXDuration)1)

/** @brief One microsecond.
 * @ingroup Foundation
 */
#define NXMicrosecond (1000 * NXNanosecond)

/** @brief One millisecond.
 * @ingroup Foundation
 */
#define NXMillisecond (1000 * NXMicrosecond)

/** @brief One second.
 * @ingroup Foundation
 */
#define NXSecond (1000 * NXMillisecond)

/** @brief One minute.
 * @ingroup Foundation
 */
#define NXMinute (60 * NXSecond)

/** @brief One hour.
 * @ingroup Foundation
 */
#define NXHour (60 * NXMinute)

/** @brief One day of 24 hours.
 * @ingroup Foundation
 */
#define NXDay (24 * NXHour)

/**
 * @brief Converts a duration to milliseconds, as used by picofuse.
 * @ingroup Foundation
 * @param duration The duration.
 * @return The number of milliseconds, rounded up, so that only a duration which
 * is zero or negative returns zero. It's UINT32_MAX if the duration is longer than
 * that.
 */
uint32_t NXDurationMilliseconds(NXDuration duration);

/**
 * @brief Returns the time since the program started.
 * @ingroup Foundation
 * @return The duration, in whole milliseconds. It never decreases, so the difference
 * between two of these is the time between them.
 */
NXDuration NXDurationTimestamp(void);

/**
 * @brief Returns a description of a duration, such as "1d2h3m4s5ms6us7ns", which
 * NXDurationFromString reads.
 * @ingroup Foundation
 * @param duration The duration.
 * @param truncate The unit to which the duration is truncated, or zero for none.
 * @return The description, which is "0s" if the duration is truncated to zero. It's in
 * the current autorelease pool.
 */
NXString *NXDurationDescription(NXDuration duration, NXDuration truncate);

/**
 * @brief Reads a duration from a string.
 * @ingroup Foundation
 * @param string The whole of it is a duration: an optional sign, then one or more
 * amounts, each a number and a unit, without spaces, such as "1h30m", "1.5s", "-250ms"
 * or "1d2h3m". The units are "d", "day" or "days", "h", "m", "s", "ms", "us" or "µs",
 * and "ns". Any part of a nanosecond is dropped.
 * @param duration Where to put the duration, which isn't changed if it can't be read.
 * @return YES if it was read, or NO if it isn't a duration or doesn't fit, which is
 * about 292 years.
 */
BOOL NXDurationFromString(NXString *string, NXDuration *duration);
