/**
 * @file NXAutoreleasePool.h
 * @brief Defines the NXAutoreleasePool class for releasing objects later.
 */
#pragma once

struct NXAutoreleasePage;

/**
 * @brief A pool of objects, which are released when the pool is drained.
 * @ingroup Foundation
 *
 * A new pool becomes the current pool of the thread which initializes it, and
 * `autorelease` adds objects to the current pool of the thread which calls it. When
 * the pool is released, its objects are released, and the pool that was current
 * before it is so again. Pools have to be released by the thread which
 * initialized them, in the opposite order.
 *
 * An object can be in a pool more than once, and is released as many times.
 *
 * Pools can't be used from an interrupt handler.
 *
 * \headerfile NXAutoreleasePool.h Foundation/Foundation.h
 */
@interface NXAutoreleasePool : NXObject {
@private
  NXAutoreleasePool *_previous;    ///< The pool which was current before
  struct NXAutoreleasePage *_page; ///< The last page of objects
}

/**
 * @brief Returns the current pool of the calling thread.
 * @return The pool, or nil if there isn't one.
 */
+ (NXAutoreleasePool *)currentPool;

/**
 * @brief Adds an object to the pool. It isn't retained, so the pool takes over a
 * reference to it.
 * @param object The object, which can't be a pool. Nothing is done if it's nil.
 *
 * This can only be called by the thread which initialized the pool.
 */
- (void)addObject:(id)object;

/**
 * @brief Releases the objects in the pool, last first. The pool can still be used.
 */
- (void)drain;

/**
 * @brief Returns the number of times objects have been added to the pool since
 * it was last drained.
 */
- (size_t)count;

@end
