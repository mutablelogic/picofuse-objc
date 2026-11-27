/**
 * @file NXCollection.h
 * @brief Defines the NXCollection protocol, for objects which hold other objects.
 */
#pragma once
#include "NXFastEnumeration.h"
#include <stddef.h>

/**
 * @brief Objects which hold other objects, such as arrays, which can be gone through
 * with a for...in loop.
 * @ingroup Foundation
 *
 * Adding or removing objects in a for...in loop panics, unless the loop then stops
 * straight away with break. Replacing an object in place doesn't.
 *
 * \headerfile NXCollection.h Foundation/Foundation.h
 */
@protocol NXCollection<NXFastEnumeration>

/**
 * @brief Returns the number of objects.
 */
- (size_t)count;

/**
 * @brief Returns YES if an object equal to this one, by isEqual:, is held.
 */
- (BOOL)containsObject:(id)object;

@end
