/**
 * @file NXFastEnumeration.h
 * @brief Defines the NXFastEnumeration protocol, for objects which can be gone
 * through with a for...in loop.
 */
#pragma once

// The state of a for...in loop. Only the name is public: GCC has it built in, and the
// fields are defined for clang where Foundation's collections are implemented.
struct __objcFastEnumerationState;

/**
 * @brief The state of a for...in loop, passed to
 * countByEnumeratingWithState:objects:count:.
 * @ingroup Foundation
 */
typedef struct __objcFastEnumerationState NXFastEnumerationState;

/**
 * @brief Objects which can be gone through with a for...in loop.
 * @ingroup Foundation
 *
 * Foundation's collections adopt it. Other classes can't yet, as the fields of the
 * loop's state are private.
 *
 * \headerfile NXFastEnumeration.h Foundation/Foundation.h
 */
@protocol NXFastEnumeration

/**
 * @brief Returns the next batch of objects for a for...in loop.
 * @param state The loop's state.
 * If the count of changes it's given changes, objc_enumerationMutation() is called,
 * which panics.
 * @param objects Room for count objects, which can be used for the batch.
 * @param count The number of objects there's room for in objects.
 * @return The number of objects in the batch, or zero when there are no more.
 */
- (unsigned long)countByEnumeratingWithState:(NXFastEnumerationState *)state
                                     objects:(id *)objects
                                       count:(unsigned long)count;

@end
