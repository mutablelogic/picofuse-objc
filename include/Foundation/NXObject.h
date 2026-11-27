/**
 * @file NXObject.h
 * @brief Defines the NXObject class, the base class for the Foundation
 * framework.
 */
#pragma once

/**
 * @brief The base class for objects in the Foundation framework.
 * @ingroup Foundation
 *
 * NXObject adds memory management to the root Object class: instances are
 * allocated, and are freed once they've been released as many times as they've
 * been retained.
 *
 * Instances are allocated in the default zone, or if there isn't one, with
 * sys_calloc(). See NXZone.
 *
 * It has no instance variables of its own: the zone and the retain count are kept in
 * memory just before the instance. That's because the compiler lays out constant
 * strings, so their superclasses can't have any.
 *
 * Any thread can retain, release and autorelease an object, except an NXAutoreleasePool,
 * which is released by the thread which initialized it. See \ref foundation_threads.
 *
 * \headerfile NXObject.h Foundation/Foundation.h
 */
@interface NXObject : Object

/**
 * @brief Allocates a new instance in the default zone, or if there isn't one,
 * with sys_calloc().
 * @return A new instance of the receiving class, or nil if the allocation
 * failed. Its retain count is one, and its instance variables are zero.
 */
+ (id)alloc;

/**
 * @brief Allocates a new instance in a specific zone.
 * @param zone The zone in which to allocate the new instance. If it's nil, this
 * is the same as alloc.
 * @return A new instance of the receiving class, or nil if the allocation
 * failed. Its retain count is one, and its instance variables are zero.
 */
+ (id)allocWithZone:(NXZone *)zone;

/**
 * @brief Allocates and initializes a new instance, as [[cls alloc] init] does.
 * @return A new instance, which isn't autoreleased: its retain count is one. It's nil
 * if the allocation or initialization failed.
 */
+ (id)new;

/**
 * @brief Frees the instance.
 *
 * This is called when the retain count reaches zero, and shouldn't be called
 * otherwise. Subclasses which override it should free their own resources, and
 * then call the superclass.
 */
- (void)dealloc;

/**
 * @brief Returns the zone in which the instance was allocated.
 * @return The zone, or nil if it wasn't allocated in a zone.
 */
- (NXZone *)zone;

/**
 * @brief Increases the retain count of the receiver.
 * @return The receiver, with its retain count incremented.
 */
- (id)retain;

/**
 * @brief Decreases the retain count of the receiver. If it becomes zero, the
 * receiver is deallocated.
 */
- (void)release;

/**
 * @brief Releases the receiver later, when the current autorelease pool of the
 * thread is drained. Panics if there's no pool.
 * @return The receiver.
 */
- (id)autorelease;

/**
 * @brief Returns a copy which can't be changed by anything else, which the caller owns
 * and has to release.
 *
 * An object which can't be changed returns itself, retained, which is what this does
 * unless it's overridden. One which can, such as an NXMutableString or NXArray, returns a
 * new object with the same contents, in the same zone.
 */
- (id)copy;

/**
 * @brief Returns a number for the object, which is the same for objects which are equal
 * by isEqual:.
 *
 * Unless it's overridden, that's the address of the object, as objects are only equal to
 * themselves. An object mustn't change while something depends on its hash, such as
 * while it's a key in a map.
 */
- (uintptr_t)hash;

/**
 * @brief Returns a string which describes the instance, for logging. Unless it's
 * overridden, that's the name of its class.
 */
- (NXString *)description;

/**
 * @brief Returns the name of the class.
 */
+ (NXString *)description;

@end
