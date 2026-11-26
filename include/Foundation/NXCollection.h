/**
 * @file NXCollection.h
 * @brief Defines the NXCollection protocol, for objects which hold other objects.
 */
#pragma once
#include <stddef.h>

/**
 * @brief Objects which hold other objects, such as arrays.
 * @ingroup Foundation
 *
 * \headerfile NXCollection.h Foundation/Foundation.h
 */
@protocol NXCollection

/**
 * @brief Returns the number of objects.
 */
- (size_t)count;

/**
 * @brief Returns YES if an object equal to this one, by isEqual:, is held.
 */
- (BOOL)containsObject:(id)object;

@end
