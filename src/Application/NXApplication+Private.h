#pragma once
#include <Application/Application.h>

@interface NXApplication (Main)

// The command line and the flags' values, from NXApplicationMain
- (void)setEnvironment:(NXEnvironment *)environment flags:(NXMap *)flags;

// YES to poll picofuse's hardware from the run loop, which feeds the watchdog
- (void)setHardware:(BOOL)hardware;

@end
