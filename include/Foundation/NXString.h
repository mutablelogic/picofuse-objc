/**
 * @file NXString.h
 * @brief Defines the NXString class, for strings.
 */
#pragma once
#include <stddef.h>

/**
 * @brief A string of UTF-8 text.
 * @ingroup Foundation
 *
 * This is the class of any string, including a constant such as `@"string"`, so it's
 * what methods take and return. Each kind of string is a subclass, which implements
 * length and cStr.
 *
 * Strings can't be changed, unless they're of a subclass which can.
 *
 * \headerfile NXString.h Foundation/Foundation.h
 */
@interface NXString : NXObject

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
 * @brief Returns YES if the other object is a string with the same contents, whatever
 * kind it is.
 */
- (BOOL)isEqual:(id)anObject;

@end
