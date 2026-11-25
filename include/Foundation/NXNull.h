/**
 * @file NXNull.h
 * @brief Defines the NXNull class, for a null value.
 */
#pragma once

/**
 * @brief A null value, as an object, for where nil can't be used.
 * @ingroup Foundation
 *
 * For example, it represents null in JSON, and can be an element of a collection.
 *
 * There's only one, which is never deallocated, and doesn't need an autorelease pool.
 *
 * \headerfile NXNull.h Foundation/Foundation.h
 */
@interface NXNull : NXObject

/**
 * @brief Returns the null value.
 */
+ (NXNull *)nullValue;

@end
