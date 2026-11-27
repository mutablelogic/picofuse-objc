#pragma once
#include <Application/Application.h>
#include <picofuse/hid.h>

/*
 * What an event source does, which NXApplication uses: it's a HID device, which it
 * registers with the application's HID instance while it's attached, and whose events
 * it handles.
 */
@protocol NXEventSourcePrivate <NXEventSource>

// Registers its HID device, or returns NO if it can't
- (BOOL)attachToHID:(hid_t *)hid;

// Deregisters its HID device, if it has one
- (void)detachFromHID:(hid_t *)hid;

// Returns YES if a HID event is from its device
- (BOOL)ownsEvent:(hid_event_t *)event;

// Handles one of its HID events, on a worker. NXApplication frees the event after.
- (void)handleEvent:(hid_event_t *)event;

@end
