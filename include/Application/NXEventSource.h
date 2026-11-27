/**
 * @file NXEventSource.h
 * @brief Defines the NXEventSource protocol, for what produces events for an application.
 */
#pragma once

/**
 * @brief Something which produces events, such as a timer, while it's attached to the
 * application with -[NXApplication attachEventSource:].
 * @ingroup Application
 *
 * The Application framework's own classes adopt it, such as NXTimer. Their events are
 * handled on the application's run loop, on any of its workers.
 *
 * \headerfile NXEventSource.h Application/Application.h
 */
@protocol NXEventSource
@end
