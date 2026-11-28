/**
 * @file NXArgument.h
 * @brief Defines the NXArgument class, for a flag on the command line.
 */
#pragma once

/**
 * @brief A flag which can be given on the command line, as --name or -n, which
 * NXEnvironment parses.
 * @ingroup Foundation
 *
 * Its type is its default's:
 * - a bool, with no default or an NXNumber of a bool
 * - an integer or an unsigned integer, with an NXNumber of one
 * - a floating point number, with an NXNumber of one
 * - a string, with an NXString
 * - a date, in ISO 8601, with an NXDate
 * - a duration, such as 1h30m, with argumentWithName:short:duration:
 *
 * NXNumber has one zero for every type, so a default of zero is a signed integer. For a
 * float or unsigned flag, the default isn't zero.
 *
 * A bool is true when it's given. The others take a value, as --name=value or
 * --name value.
 *
 * \headerfile NXArgument.h Foundation/Foundation.h
 */
@interface NXArgument : NXObject {
@private
  NXString *_name;      ///< The long name, without --
  NXString *_shortName; ///< The short name, without -, or nil
  id _default;          ///< The default
  int _type;            ///< picofuse's type
}

/**
 * @brief Returns a bool flag, which is NO unless it's given.
 * @param name The long name, without --.
 * @param shortName The short name, without -, or nil.
 * @return The flag, or nil if a name is empty.
 */
+ (NXArgument *)argumentWithName:(NXString *)name short:(NXString *)shortName;

/**
 * @brief Returns a flag whose type and default are a value's.
 * @param name The long name, without --.
 * @param shortName The short name, without -, or nil.
 * @param value The default: an NXNumber, an NXString or an NXDate.
 * @return The flag, or nil if a name is empty, or the default is nil or of another
 * class.
 */
+ (NXArgument *)argumentWithName:(NXString *)name short:(NXString *)shortName default:(id)value;

/**
 * @brief Returns a duration flag, whose value is an NXNumber of nanoseconds.
 * @param name The long name, without --.
 * @param shortName The short name, without -, or nil.
 * @param value The default.
 * @return The flag, or nil if a name is empty.
 */
+ (NXArgument *)argumentWithName:(NXString *)name
                           short:(NXString *)shortName
                        duration:(NXDuration)value;

/**
 * @brief Returns the long name.
 */
- (NXString *)name;

/**
 * @brief Returns the short name, or nil.
 */
- (NXString *)shortName;

@end
