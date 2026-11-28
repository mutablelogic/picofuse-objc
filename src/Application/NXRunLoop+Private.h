#pragma once
#include <Application/Application.h>
#include <picofuse/sys.h>

/*
 * What the Application framework uses of a run loop, which programs don't.
 */

// Offered each event first, on the worker which takes it, in its autorelease pool.
// Returns YES if it handled the event, which isn't then an object to dispatch.
typedef BOOL (*NXRunLoopEventHandler)(sys_event_t event);

// Called now and then on worker 0, while the run loop runs
typedef void (*NXRunLoopPoll)(void);

@interface NXRunLoop (Private)

// The queue of the run which is in progress, or NULL. Events can be pushed to it
// directly, as long as the event handler handles them.
- (sys_event_queue_t *)queue;

// Sets the event handler and the poll function, which can be NULL, for the next run
- (void)setEventHandler:(NXRunLoopEventHandler)handler poll:(NXRunLoopPoll)poll;

@end
