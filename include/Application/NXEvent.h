/**
 * @file NXEvent.h
 * @brief Defines the NXEvent protocol, for what a run loop dispatches.
 */
#pragma once

/**
 * @brief Something a run loop dispatches, on one of its workers.
 * @ingroup Application
 *
 * \headerfile NXEvent.h Application/Application.h
 */
@protocol NXEvent

/**
 * @brief Handles the event. It's called once, on whichever worker takes the event, in an
 * autorelease pool of its own.
 */
- (void)dispatch;

@end
