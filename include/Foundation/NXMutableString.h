/**
 * @file NXMutableString.h
 * @brief Defines the NXMutableString class, for strings which can be changed.
 */
#pragma once

/**
 * @brief A string which can be changed.
 * @ingroup Foundation
 *
 * It shouldn't be changed while another thread is using it.
 *
 * Methods which make the string longer return NO if there isn't enough memory, and
 * don't change it.
 *
 * \headerfile NXMutableString.h Foundation/Foundation.h
 */
@interface NXMutableString : NXString {
@private
  char *_data;      ///< The contents, or NULL if there's no capacity
  size_t _length;   ///< The length, without the null terminator
  size_t _capacity; ///< The length there's room for, without the null terminator
}

/**
 * @brief Returns an empty string, with room for a number of bytes.
 */
+ (id)stringWithCapacity:(size_t)capacity;

/**
 * @brief Initializes an empty string, with room for a number of bytes.
 */
- (id)initWithCapacity:(size_t)capacity;

/**
 * @brief Returns the length that the string can be before it needs more memory.
 */
- (size_t)capacity;

/**
 * @brief Appends another string, which can be this one. Nothing is done if it's nil.
 */
- (BOOL)appendString:(NXString *)other;

/**
 * @brief Appends a null-terminated string. Nothing is done if it's NULL.
 */
- (BOOL)appendCString:(const char *)cStr;

/**
 * @brief Appends what's made from a format and arguments, which can include this string.
 */
- (BOOL)appendFormat:(NXString *)format, ...;

/**
 * @brief Removes whitespace, such as spaces, tabs and line endings, from the start and
 * end.
 */
- (void)trimWhitespace;

/**
 * @brief Removes another string from the start, and returns YES, if this starts with it.
 * Nothing is done, and it returns NO, if that's nil or empty.
 */
- (BOOL)trimPrefix:(NXString *)prefix;

/**
 * @brief Removes another string from the end, and returns YES, if this ends with it.
 * Nothing is done, and it returns NO, if that's nil or empty.
 */
- (BOOL)trimSuffix:(NXString *)suffix;

/**
 * @brief Changes letters to uppercase, if they're in the Latin-1 character set.
 */
- (void)toUppercase;

/**
 * @brief Changes letters to lowercase, if they're in the Latin-1 character set.
 */
- (void)toLowercase;

@end
