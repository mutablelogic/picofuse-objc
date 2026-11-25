/**
 * @file NXThread.h
 * @brief Defines the NXThread class, for threads and the cores they run on.
 */
#pragma once
#include "NXDuration.h"

/**
 * @brief Runs methods in threads, and provides information about cores.
 * @ingroup Foundation
 *
 * A Pico has one thread for each core: only the thread on core 0 can run a method
 * in another thread, which is on core 1, and only if nothing is already running
 * there.
 *
 * \headerfile NXThread.h Foundation/Foundation.h
 */
@interface NXThread : NXObject

/**
 * @brief Pauses the calling thread.
 * @param duration How long to pause, which is rounded up to a millisecond. It
 * doesn't if this is zero or negative.
 */
+ (void)sleepForDuration:(NXDuration)duration;

/**
 * @brief Stops the program, and doesn't return.
 *
 * On a Pico, it's only the calling core which stops, and the other carries on. On
 * other systems the program is aborted.
 */
+ (void)halt;

/**
 * @brief Returns the number of cores.
 */
+ (uint8_t)numberOfCores;

/**
 * @brief Returns the number of the core which the calling thread is running on,
 * starting with zero. Other than on a Pico, that can change at any time.
 */
+ (uint8_t)coreNumber;

/**
 * @brief Runs a method in a new thread.
 * @param selector The selector for the method, which has no arguments. What it
 * returns isn't used, and can't be a struct, a union, a complex number or a long
 * double.
 * @param target The object or class which has the method. If it's an NXObject, it's
 * retained until the method returns.
 * @return YES if the thread was started, or NO if the target doesn't have the
 * method, the method has arguments or can't be called because of what it returns, or no
 * thread is available.
 *
 * The method has its own autorelease pool.
 */
+ (BOOL)run:(SEL)selector target:(id)target;

/**
 * @brief Runs a method in a new thread on a specific core.
 * @param selector The selector for the method, which has no arguments.
 * @param target The object or class which has the method.
 * @param core The number of the core.
 * @return YES if the thread was started. As well as the reasons for run:target:, it's
 * NO if there's no such core, and always on a Mac, where a core can't be chosen.
 *
 * Otherwise this is the same as run:target:.
 */
+ (BOOL)run:(SEL)selector target:(id)target core:(uint8_t)core;

/**
 * @brief Runs a method which has an argument in a new thread.
 * @param selector The selector for the method, which has one argument, an object.
 * @param target The object or class which has the method.
 * @param argument The argument, which may be nil. If it's an NXObject, it's retained
 * until the method returns.
 * @return YES if the thread was started, or NO if the target doesn't have the
 * method, the method doesn't have one argument which is an object, or no thread is
 * available.
 *
 * Otherwise this is the same as run:target:.
 */
+ (BOOL)run:(SEL)selector target:(id)target argument:(id)argument;

/**
 * @brief Runs a method which has an argument in a new thread on a specific core.
 * @param selector The selector for the method, which has one argument, an object.
 * @param target The object or class which has the method.
 * @param argument The argument, which may be nil. If it's an NXObject, it's retained
 * until the method returns.
 * @param core The number of the core.
 * @return YES if the thread was started, or NO for the same reasons as
 * run:target:core:, or if the method doesn't have one argument which is an object.
 */
+ (BOOL)run:(SEL)selector
     target:(id)target
   argument:(id)argument
       core:(uint8_t)core;

@end
