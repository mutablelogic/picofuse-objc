/**
 * @file mutex.h
 * @brief Object synchronization and locking functions for the Objective-C
 * runtime.
 *
 * These are what `@synchronized` calls. They can be used from any thread once
 * sys_init() has been called, but not from an interrupt handler.
 */
#pragma once
#include "runtime.h"

/**
 * @def OBJC_SYNC_CAPACITY
 * @ingroup objc
 * @brief Maximum number of objects which can be locked at any one time, by all
 * threads together. Exceeding it panics.
 */
#ifndef OBJC_SYNC_CAPACITY
#define OBJC_SYNC_CAPACITY 32
#endif

/**
 * @brief Acquire a lock on the specified object for thread synchronization.
 * @ingroup objc
 * @param obj The object to lock. Nothing is done if it's nil.
 * @return 0 on success, or a non-zero error code on failure.
 *
 * If another thread holds the lock, this blocks until it's released. A thread
 * can lock an object again which it has already locked, as long as it unlocks it
 * as many times.
 */
int objc_sync_enter(id obj);

/**
 * @brief Release a lock on the specified object.
 * @ingroup objc
 * @param obj The object to unlock. Must be the same object passed to
 * objc_sync_enter().
 * @return 0 on success, or a non-zero error code if the current thread doesn't
 * hold the lock.
 */
int objc_sync_exit(id obj);
