/**
 * @file NXZone.h
 * @brief Defines the NXZone class for memory management.
 */
#pragma once
#include <picofuse/sys.h>

/**
 * @brief A region of memory, from which objects and other memory can be
 * allocated.
 * @ingroup Foundation
 *
 * A zone is a chain of picofuse arenas. It starts with one, and another is added
 * whenever there isn't room in those it has.
 *
 * The first zone created becomes the default zone, in which objects are
 * allocated. When it's deallocated, there's no default zone until another zone is
 * created.
 *
 * \headerfile NXZone.h Foundation/Foundation.h
 */
@interface NXZone : NXObject {
@private
  size_t _size;            ///< Size of each arena, unless it needs to be larger
  sys_mem_arena_t *_arena; ///< The first arena
}

/**
 * @brief Returns the default zone.
 * @return The default zone, or nil if there isn't one.
 */
+ (NXZone *)defaultZone;

/**
 * @brief Creates a new zone.
 * @param size The initial capacity of the zone in bytes. Some of that is used to
 * keep track of each allocation.
 * @return A new zone, or nil if the allocation failed. It should be released when
 * it's no longer needed.
 *
 * If there's no default zone, the new zone becomes the default zone.
 */
+ (id)zoneWithSize:(size_t)size;

/**
 * @brief Frees the zone and its memory. Panics if any memory allocated from the
 * zone hasn't been freed.
 */
- (void)dealloc;

/**
 * @brief Allocates a block of memory from the zone.
 * @param size The number of bytes to allocate.
 * @return A pointer to the allocated memory, which isn't initialized, or NULL if
 * the size is zero or the allocation failed.
 */
- (void *)allocWithSize:(size_t)size;

/**
 * @brief Frees a block of memory that was allocated from the zone. Panics if it
 * wasn't.
 * @param ptr A pointer to the memory block. Nothing is done if it's NULL.
 */
- (void)free:(void *)ptr;

/**
 * @brief Returns the number of blocks of memory which are allocated.
 */
- (size_t)count;

/**
 * @brief Returns the capacity of the zone in bytes.
 */
- (size_t)bytesTotal;

/**
 * @brief Returns the number of bytes which are allocated.
 */
- (size_t)bytesUsed;

/**
 * @brief Returns the number of bytes which aren't allocated. Not all of it can
 * be, as some is used to keep track of each allocation.
 */
- (size_t)bytesFree;

@end
