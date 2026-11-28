/**
 * @file Foundation.h
 * @brief Foundation framework header
 * @defgroup Foundation Foundation Framework
 * @ingroup objc
 *
 * Foundational classes and types.
 *
 * @section foundation_threads Threads and mutable objects
 *
 * - Any object can be retained, released and autoreleased by any thread, except an
 *   NXAutoreleasePool. The retain count is changed atomically, and the thread whose
 *   release deallocates an object sees what other threads wrote to it first.
 * - Each thread has its own autorelease pools, and a thread started by NXThread has one.
 *   A pool can't be retained or autoreleased: it's released by the thread which
 *   initialized it, while it's that thread's current pool.
 * - An object which can't change, which is an NXString (but not an NXMutableString), an
 *   NXNumber, an NXDate or NXNull, can be used by any number of threads at once.
 * - An object which can change, which is an NXArray, an NXMap, an NXMutableString or an
 *   NXData, can be read by any number of threads at once, as long as none of them
 *   changes it. To change it, every other thread has to be kept out, by holding an
 *   NXLock, an NXCondition or \@synchronized around the reads as well as the changes.
 * - They don't lock themselves, as that wouldn't be enough: a lock in each method
 *   doesn't make several calls, such as looking a key up and then adding it, happen as
 *   one, can't cover a for...in loop, and doesn't stop another thread releasing an
 *   object which objectAtIndex: or objectForKey: returned, as they aren't retained. To
 *   give another thread an array or map which won't change underneath it, give it a
 *   -copy.
 * - Misuse is caught, best effort, in every build, as Go catches it for maps: an
 *   NXArray, NXMap, NXMutableString or NXData panics if two threads change it at once,
 *   if it's read while another thread changes it, or if it's changed in the middle of
 *   a change, as from an isEqual: which the change called. It's caught when the threads
 *   overlap where it's checked, so not always, and costs a read and a comparison.
 * - An NXStream or an NXScanner is used by one thread at a time. Streams of the
 *   standard input share a byte which has been peeked at, so only one thread reads the
 *   standard input.
 * - An NXZone can be used by any thread, as it locks itself.
 * - A class can be used for the first time by any thread: if another thread is sending
 *   it +initialize, the thread waits until that's done.
 * - What a thread wrote to an object before it hands it to another is seen by that
 *   thread if it's handed over with an NXLock, an NXCondition, an NXWaitGroup, an
 *   NXAtomic which is set and then read, or as the argument of a method which NXThread
 *   runs in a new thread. Not otherwise: a plain variable isn't enough.
 * - None of this is for interrupts. On a Pico, an interrupt can't send a message, so it
 *   posts an event instead.
 */
#pragma once
#include <runtime/gcc/objc.h>

#if __OBJC__

// Forward Declaration of classes
@class NXArchive;
@class NXArray;
@class NXAutoreleasePool;
@class NXData;
@class NXMap;
@class NXDate;
@class NXMutableString;
@class NXNull;
@class NXNumber;
@class NXObject;
@class NXScanner;
@class NXStream;
@class NXString;
@class NXThread;
@class NXZone;

// Types
#include "NXComparisonResult.h"
#include "NXDuration.h"
#include "NXHashAlgorithm.h"
#include "NXNotFound.h"
#include "NXLog.h"

// Protocols
#include "NXFastEnumeration.h"
#include "NXCollection.h"
#include "NXLocking.h"

// Class Definitions
#include "NXObject.h"
#include "NXAutoreleasePool.h"
#include "NXNull.h"
#include "NXNumber.h"
#include "NXString.h"
#include "NXConstantString.h"
#include "NXDate.h"
#include "NXMutableString.h"
#include "NXArray.h"
#include "NXMap.h"
#include "NXData.h"
#include "NXStream.h"
#include "NXScanner.h"
#include "NXArchive.h"
#include "NXThread.h"
#include "NXLock.h"
#include "NXCondition.h"
#include "NXWaitGroup.h"
#include "NXAtomic.h"
#include "NXZone.h"
#include "NXArgument.h"
#include "NXEnvironment.h"

#endif // __OBJC__
