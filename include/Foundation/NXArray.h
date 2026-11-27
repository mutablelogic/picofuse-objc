/**
 * @file NXArray.h
 * @brief Defines the NXArray class, for ordered lists of objects.
 */
#pragma once
#include "NXCollection.h"
#include <stdarg.h>
#include <stddef.h>

/**
 * @brief An ordered list of objects, which can be changed.
 * @ingroup Foundation
 *
 * The objects are retained while they're in the array, and released when they're removed
 * or the array is deallocated. They're kept one after another in memory from the array's
 * zone, which is twice as big when more room is needed. An array can't hold nil, so
 * NXNull is used instead.
 *
 * A for...in loop goes through the objects in order. Adding or removing objects in the
 * loop panics, unless it then stops with break, but replacing one doesn't.
 *
 * Any number of threads can read an array at once, but while one changes it, no other thread can use it, and it doesn't lock itself. See \ref foundation_threads.
 *
 * \headerfile NXArray.h Foundation/Foundation.h
 */
@interface NXArray : NXObject <NXCollection> {
@private
  id *_objects;     ///< The objects, or NULL if there's no room yet
  size_t _count;    ///< The number of objects
  size_t _capacity; ///< The number of objects there's room for
  unsigned long _mutations; ///< Counts objects added and removed, for for...in loops
}

/**
 * @brief Returns an empty array.
 */
+ (id)array;

/**
 * @brief Returns an empty array with room for a number of objects.
 * @return The array, or nil if there isn't enough memory.
 */
+ (id)arrayWithCapacity:(size_t)capacity;

/**
 * @brief Returns an array of objects, which ends with nil.
 * @return The array, or nil if there isn't enough memory.
 */
+ (id)arrayWithObjects:(id)firstObject, ...;

/**
 * @brief Initializes an empty array with room for a number of objects.
 */
- (id)initWithCapacity:(size_t)capacity;

/**
 * @brief Initializes an array of objects, which ends with nil.
 */
- (id)initWithObjects:(id)firstObject, ...;

/**
 * @brief Returns the number of objects.
 */
- (size_t)count;

/**
 * @brief Returns the number of objects there's room for, before more memory is needed.
 */
- (size_t)capacity;

/**
 * @brief Returns the object at an index, or nil if there isn't one.
 */
- (id)objectAtIndex:(size_t)index;

/**
 * @brief Returns the first object, or nil if the array is empty.
 */
- (id)firstObject;

/**
 * @brief Returns the last object, or nil if the array is empty.
 */
- (id)lastObject;

/**
 * @brief Returns the index of the first object equal to one, by isEqual:, or NXNotFound.
 */
- (size_t)indexOfObject:(id)object;

/**
 * @brief Returns YES if an object equal to one, by isEqual:, is in the array.
 */
- (BOOL)containsObject:(id)object;

/**
 * @brief Adds an object to the end.
 * @return YES if it was added, or NO if it's nil or there isn't enough memory.
 */
- (BOOL)appendObject:(id)object;

/**
 * @brief Inserts an object at an index, moving those from there along.
 * @param index From zero to the number of objects, which adds it to the end.
 * @return YES if it was inserted, or NO if it's nil, the index is beyond the end, or
 * there isn't enough memory.
 */
- (BOOL)insertObject:(id)object atIndex:(size_t)index;

/**
 * @brief Replaces the object at an index.
 * @return YES if it was replaced, or NO if it's nil or there isn't an object there.
 */
- (BOOL)replaceObjectAtIndex:(size_t)index withObject:(id)object;

/**
 * @brief Removes the object at an index, moving those after it back.
 * @return YES if it was removed, or NO if there isn't an object there.
 */
- (BOOL)removeObjectAtIndex:(size_t)index;

/**
 * @brief Removes every object equal to one, by isEqual:.
 * @return The number which were removed.
 */
- (size_t)removeObject:(id)object;

/**
 * @brief Removes the last object.
 * @return YES if it was removed, or NO if the array is empty.
 */
- (BOOL)removeLastObject;

/**
 * @brief Removes every object, but keeps the room for them.
 */
- (void)removeAllObjects;

/**
 * @brief Returns YES if another object is an array of equal objects, by isEqual:, in the
 * same order.
 */
- (BOOL)isEqual:(id)anObject;

/**
 * @brief Returns a hash of the objects, in order, which is the same for equal arrays.
 */
- (uintptr_t)hash;

/**
 * @brief Returns a new array of the same objects, which are retained by it too, or nil if
 * there isn't enough memory. The caller owns it and has to release it.
 */
- (id)copy;

/**
 * @brief Returns the descriptions of the objects, such as "[1, 2, three]".
 */
- (NXString *)description;

/**
 * @brief Returns a new array with some of the objects, in the same order.
 * @param index The index of the first.
 * @param count The number of them.
 * @return The array, or nil if they'd run past the end or there isn't enough memory.
 */
- (NXArray *)subarrayFromIndex:(size_t)index count:(size_t)count;

/**
 * @brief Returns the objects joined into a string, with a separator between them.
 * Strings are joined as they are, and other objects by their description.
 * @param separator The separator, or nil for none.
 * @return The string, which is empty if there are no objects, or nil if there isn't
 * enough memory.
 */
- (NXString *)componentsJoinedByString:(NXString *)separator;

/**
 * @brief Sorts the objects, by sending each a comparator, such as \@selector(compare:),
 * with the other as its argument, which returns an NXComparisonResult.
 * @return YES, or NO if the comparator is NULL or there isn't enough memory, when the
 * order isn't changed.
 *
 * Objects which are the same keep their order. It needs room for half the objects in
 * the array's zone while it sorts. Sorting in a for...in loop over the array panics.
 */
- (BOOL)sortUsingSelector:(SEL)comparator;

@end
