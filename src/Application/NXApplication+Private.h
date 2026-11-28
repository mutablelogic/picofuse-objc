#pragma once
#include <Application/Application.h>

@interface NXApplication (Main)

// The command line and the flags' values, from NXApplicationMain
- (void)setEnvironment:(NXEnvironment *)environment flags:(NXMap *)flags;

// YES to poll picofuse's hardware from the run loop, which feeds the watchdog
- (void)setHardware:(BOOL)hardware;

// YES if the watchdog restarted the device, which the delegate is told when it starts
- (void)setWatchdogReset:(BOOL)reset;

// Terminates it on a signal, which the delegate is told
- (void)terminateWithSignal:(int)signal;

@end
