/**
 * @file NXString.h
 * @brief Defines the NXString class, for strings.
 */
#pragma once
#include <stdarg.h>
#include <stddef.h>

@class NXArray;

/**
 * @brief A string of UTF-8 text.
 * @ingroup Foundation
 *
 * This is the class of any string, including a constant such as `@"string"`, so it's
 * what methods take and return. Other strings copy what they're made from.
 *
 * Strings can't be changed, unless they're an NXMutableString. They don't contain a zero
 * byte.
 *
 * A format can have these in it:
 *
 * | Specifier        | Argument                                                  |
 * | ---------------- | --------------------------------------------------------- |
 * | `%c`             | Character                                                 |
 * | `%s`             | Null-terminated string                                    |
 * | `%d` `%u`        | 32-bit signed or unsigned integer                         |
 * | `%x` `%X`        | 32-bit unsigned integer, in hexadecimal                   |
 * | `%b` `%o`        | 32-bit unsigned integer, in binary or octal               |
 * | `%f` `%e` `%g`   | Floating point, also `%F`, `%E` and `%G`                  |
 * | `%p`             | Pointer                                                   |
 * | `%@`             | Object, which is replaced by its description, or `<nil>`  |
 * | `%t`             | NXDuration                                                |
 * | `%%`             | None, as it's a percent sign                              |
 *
 * With an `l`, as in `%ld`, an integer is 64 bits, on every system. With a `z`, it's a
 * size_t. There can also be a minimum width, as in `%80d`, a precision for floating
 * point, as in `%.3f`, and the flags `-` (on the left), `0` (pad with zeros), `+` (show
 * the sign), space, and `#` (show the base). They have no effect on `%@` and `%t`.
 *
 * The description of an object may be needed twice, as a long string is formatted once
 * to find out how long it is.
 *
 * Strings which are returned by class methods are in the current autorelease pool.
 * Methods which make strings return nil if there isn't enough memory.
 *
 * Subclasses implement length and cStr.
 *
 * \headerfile NXString.h Foundation/Foundation.h
 */
@interface NXString : NXObject

/**
 * @brief Returns an empty string.
 */
+ (id)string;

/**
 * @brief Returns a string with the contents of another, which is empty if that's nil.
 */
+ (id)stringWithString:(NXString *)other;

/**
 * @brief Returns a string with the contents of a null-terminated string, which is empty
 * if that's NULL.
 */
+ (id)stringWithCString:(const char *)cStr;

/**
 * @brief Returns a string made from a format and arguments.
 */
+ (id)stringWithFormat:(NXString *)format, ...;

/**
 * @brief Initializes a string with a number of bytes, or those before the first which is
 * zero.
 */
- (id)initWithBytes:(const void *)bytes length:(size_t)length;

/**
 * @brief Initializes a string with the contents of another, which is empty if that's
 * nil.
 */
- (id)initWithString:(NXString *)other;

/**
 * @brief Returns a string from one in quotes, with its escapes decoded, or nil if it isn't
 * one.
 * @param quoted The whole of it is a string in ' or " quotes, such as a token from a
 * scanner with NXScannerQuotes. The escapes are \\' \\" \\\\ \\/ \\b \\f \\n \\r \\t and \\uXXXX.
 * @return The string, which stops at the first zero, from \\u0000, or nil if it isn't
 * closed, has anything after the closing quote, has an escape which isn't known, or
 * there isn't enough memory.
 */
+ (id)stringWithQuotedString:(NXString *)quoted;

/**
 * @brief Initializes a string from one in quotes, with its escapes decoded.
 */
- (id)initWithQuotedString:(NXString *)quoted;

/**
 * @brief Initializes a string with the contents of a null-terminated string, which is
 * empty if that's NULL.
 */
- (id)initWithCString:(const char *)cStr;

/**
 * @brief Initializes a string with a format and arguments.
 */
- (id)initWithFormat:(NXString *)format, ...;

/**
 * @brief Initializes a string with a format and a list of arguments.
 */
- (id)initWithFormat:(NXString *)format arguments:(va_list)args;

/**
 * @brief Returns the length in bytes, which doesn't include the null terminator.
 */
- (size_t)length;

/**
 * @brief Returns the contents, as a null-terminated string. It can be used for as long
 * as the string exists, and isn't changed.
 */
- (const char *)cStr;

/**
 * @brief Returns the number of runes, which are Unicode code points.
 */
- (size_t)runeCount;

/**
 * @brief Returns YES if the other object is a string with the same contents, whatever
 * kind it is.
 */
- (BOOL)isEqual:(id)anObject;

/**
 * @brief Returns a hash of the contents, which is the same for equal strings.
 */
- (uintptr_t)hash;

/**
 * @brief Compares the string with another, byte by byte. If that's nil, it's compared
 * with an empty string.
 */
- (NXComparisonResult)compare:(NXString *)other;

/**
 * @brief Returns YES if the string starts with another, as it does with nil or an empty
 * string.
 */
- (BOOL)hasPrefix:(NXString *)prefix;

/**
 * @brief Returns YES if the string ends with another, as it does with nil or an empty
 * string.
 */
- (BOOL)hasSuffix:(NXString *)suffix;

/**
 * @brief Returns YES if the string has another in it, as it does nil or an empty string.
 */
- (BOOL)containsString:(NXString *)other;

/**
 * @brief Returns the index, in bytes, of the first place that another string is in this
 * one, or NXNotFound. It's zero for nil or an empty string.
 */
- (size_t)indexOfSubstring:(NXString *)other;

/**
 * @brief Returns the parts of the string between a separator, as new strings.
 * @param separator The separator, which can be more than one character.
 * @return The parts, in order, including empty ones: "a,,b" is "a", "" and "b", and an
 * empty string is one empty part. If the separator isn't found, or is nil or empty,
 * it's the string on its own. Joining the parts with componentsJoinedByString: gives
 * the string back. Returns nil if there isn't enough memory.
 */
- (NXArray *)componentsSeparatedByString:(NXString *)separator;

/**
 * @brief Returns the words of the string, which are between runs of whitespace, as new
 * strings.
 * @return The words, in order, without empty ones: "  a  b " is "a" and "b", and a
 * string of only whitespace has none. Whitespace is Unicode's, as trimWhitespace
 * removes. Returns nil if there isn't enough memory.
 */
- (NXArray *)componentsSeparatedByWhitespace;

/**
 * @brief Returns the string itself.
 */
- (NXString *)description;

@end
