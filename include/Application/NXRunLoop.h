/**
 * @file NXRunLoop.h
 * @brief Defines the NXRunLoop class, which dispatches events on one or more cores.
 */
#pragma once
#include "NXEvent.h"
#include <picofuse/sys.h>
#include <stdint.h>

/**
 * @brief What a run loop tells its delegate. Each method is optional.
 * @ingroup Application
 *
 * \headerfile NXRunLoop.h Application/Application.h
 */
@protocol NXRunLoopDelegate
@optional


/**
 * @brief Called on worker 0 when the run loop starts. Events can be posted from here, and
 * none are dispatched, on any worker, until it returns.
 */
- (void)runLoopDidStart:(NXRunLoop *)runLoop;

/**
 * @brief Called on the thread which ran the run loop, once it has stopped, every event
 * which was posted has been dispatched, and every worker has finished.
 */
- (void)runLoopWillStop:(NXRunLoop *)runLoop;

@end

/**
 * @brief Dispatches events which are posted to it, on one or more workers, until it's
 * shut down.
 * @ingroup Application
 *
 * It's picofuse's sys_runloop. The thread which runs it is worker 0. On a Pico, other
 * workers are on the other cores, and on a Mac or Linux, other threads. Every worker
 * takes events from the same queue, in the order they were posted, so with more than one
 * worker, events are dispatched at the same time on different cores, and what they do
 * has to be safe for that (see \ref foundation_threads). Only one run loop runs at a
 * time, and it can be run again once it's stopped.
 *
 * Events can be posted from any thread while it runs, but not from an interrupt.
 *
 * \headerfile NXRunLoop.h Application/Application.h
 */
@interface NXRunLoop : NXObject {
@private
  size_t _capacity;         ///< How many events can wait
  id<NXRunLoopDelegate> _delegate; ///< Not retained
  sys_event_queue_t *_queue; ///< While it runs, or NULL
  void *_handler;           ///< For the Application framework, or NULL
  void *_poll;              ///< For the Application framework, or NULL
}

/**
 * @brief Initializes a run loop with room for 32 events to wait.
 */
- (id)init;

/**
 * @brief Initializes a run loop with room for a number of events to wait.
 */
- (id)initWithCapacity:(size_t)capacity;

/**
 * @brief Returns the run loop which is running, or nil if none is.
 */
+ (NXRunLoop *)runningRunLoop;

/**
 * @brief Returns the delegate, which isn't retained.
 */
- (id<NXRunLoopDelegate>)delegate;

/**
 * @brief Sets the delegate, which isn't retained.
 */
- (void)setDelegate:(id<NXRunLoopDelegate>)delegate;

/**
 * @brief Runs, dispatching events until it's shut down. The thread which calls this is
 * worker 0.
 * @param workers The number of workers, including this one, or 0 for one on every core.
 * More than there are cores is as many as there are.
 * @return The status it was shut down with, or -1 if it couldn't run, as another run
 * loop is running or there isn't enough memory.
 */
- (int)runWithWorkers:(uint8_t)workers;

/**
 * @brief Returns YES if it's running.
 */
- (BOOL)isRunning;

/**
 * @brief Stops it taking events, and once those posted have been dispatched, makes
 * runWithWorkers: return a status. It does nothing if it isn't running.
 */
- (void)shutdownWithStatus:(int)status;

/**
 * @brief Posts an event, which is retained until it's been dispatched.
 * @return YES, or NO if it isn't running, it's been shut down, or there's no room.
 */
- (BOOL)post:(id<NXEvent>)event;

/**
 * @brief Posts an event which sends a message, with no arguments, to a target. The
 * target is retained until it's been sent, if it's an NXObject.
 * @return YES, or NO if the target doesn't have the method, the method has arguments or
 * returns something which can't be ignored (a struct, for example), or it couldn't be
 * posted.
 */
- (BOOL)perform:(SEL)selector target:(id)target;

/**
 * @brief Posts an event which sends a message, with an object as its argument, to a
 * target. The target and argument are retained until it's been sent, if they're
 * NXObjects.
 * @return YES, or NO for the same reasons as perform:target:, or if the method doesn't
 * have one argument which is an object.
 */
- (BOOL)perform:(SEL)selector target:(id)target argument:(id)argument;

@end
