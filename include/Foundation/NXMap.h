/**
 * @file NXMap.h
 * @brief Defines the NXMap class, for objects found by keys.
 */
#pragma once
#include "NXCollection.h"
#include <stddef.h>
#include <stdint.h>

/**
 * @brief Objects found by keys, which can be changed.
 * @ingroup Foundation
 *
 * Any object can be a key, as they're found by hash and isEqual:. A map keeps a copy of
 * each key, so changing the key afterwards doesn't change the map: for a string which
 * can't change, the copy is the same string. Objects are retained while they're in the
 * map, and released when they're removed or replaced or the map is deallocated. Neither
 * a key nor an object can be nil, so NXNull is used instead.
 *
 * The keys and objects are kept in a table in memory from the map's zone, which is twice
 * as big when it would be three-quarters full. The order of keys isn't defined.
 *
 * A for...in loop goes through the keys. Adding or removing keys in the loop panics,
 * unless it then stops with break, but setting the object for a key which is there
 * doesn't.
 *
 * A map shouldn't be changed by one thread while another uses it.
 *
 * \headerfile NXMap.h Foundation/Foundation.h
 */
@interface NXMap : NXObject <NXCollection> {
@private
  void *_entries;   ///< The table of keys and objects, or NULL if there's no room yet
  size_t _count;    ///< The number of keys
  size_t _capacity; ///< The size of the table, which is a power of two, or zero
  unsigned _shift;  ///< The bits of a hash which aren't used for the size
  unsigned long _mutations; ///< Counts keys added and removed, for for...in loops
  uintptr_t _changing;      ///< The thread which is changing it, or zero
}

/**
 * @brief Returns an empty map.
 */
+ (id)map;

/**
 * @brief Returns an empty map with room for a number of keys.
 * @return The map, or nil if there isn't enough memory.
 */
+ (id)mapWithCapacity:(size_t)capacity;

/**
 * @brief Returns a map of keys and objects, in pairs of a key and then its object, which
 * end with nil.
 * @return The map, or nil if there isn't enough memory.
 */
+ (id)mapWithKeysAndObjects:(id)firstKey, ...;

/**
 * @brief Initializes an empty map with room for a number of keys.
 */
- (id)initWithCapacity:(size_t)capacity;

/**
 * @brief Returns the number of keys.
 */
- (size_t)count;

/**
 * @brief Returns the object for a key, or nil if there isn't one.
 */
- (id)objectForKey:(id)key;

/**
 * @brief Returns YES if there's an object for a key.
 */
- (BOOL)containsObject:(id)key;

/**
 * @brief Sets the object for a key, replacing any it had.
 * @return YES if it was set, or NO if the key or object is nil, or there isn't enough
 * memory.
 */
- (BOOL)setObject:(id)object forKey:(id)key;

/**
 * @brief Removes a key and its object.
 * @return YES if it was removed, or NO if there wasn't one.
 */
- (BOOL)removeObjectForKey:(id)key;

/**
 * @brief Removes every key and object, but keeps the room for them.
 */
- (void)removeAllObjects;

/**
 * @brief Returns the keys, in no particular order, or nil if there isn't enough memory.
 */
- (NXArray *)allKeys;

/**
 * @brief Returns the objects, in the same order as allKeys, or nil if there isn't enough
 * memory.
 */
- (NXArray *)allObjects;

/**
 * @brief Returns YES if another object is a map with equal keys, by isEqual:, which have
 * equal objects.
 */
- (BOOL)isEqual:(id)anObject;

/**
 * @brief Returns a hash of the keys and objects, which is the same for equal maps.
 */
- (uintptr_t)hash;

/**
 * @brief Returns a new map of the same keys and objects, or nil if there isn't enough
 * memory. The caller owns it and has to release it.
 */
- (id)copy;

/**
 * @brief Returns the descriptions of the keys and objects, such as "{a: 1, b: 2}".
 */
- (NXString *)description;

@end
