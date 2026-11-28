// Prints the temperature sensor's reading whenever it changes, which is read every
// --interval, its default on a Pico, with no command line, until it's interrupted
#include <Application/Application.h>

@interface Thermometer : NXObject <NXApplicationDelegate> {
@private
  NXAnalogInput *_sensor;
}
@end

@implementation Thermometer

+ (NXArray *)commandLineFlags {
  return [NXArray arrayWithObjects:[NXArgument argumentWithName:@"interval"
                                                          short:@"i"
                                                       duration:NXSecond],
                                   nil];
}

- (void)dealloc {
  [_sensor release];
  [super dealloc];
}

// HID reads it every interval, and this is sent when the reading changes
- (void)changed:(NXAnalogInput *)sensor {
  NXLog(@"%.1fC", (double)[sensor floatValue]);
}

- (void)applicationDidStart:(NXApplication *)application watchdogReset:(BOOL)reset {
  (void)reset;
  NXDuration interval = [[[application flags] objectForKey:@"interval"] int64Value];
  if (interval <= 0) {
    NXLog(@"The interval has to be more than zero");
    [application terminateWithStatus:2];
    return;
  }

  // The sensor, which sends its readings while it's attached
  _sensor = [[NXAnalogInput temperatureWithInterval:interval
                                             target:self
                                           selector:@selector(changed:)] retain];
  if (![application attachEventSource:_sensor]) {
    NXLog(@"There's no temperature sensor");
    [application terminateWithStatus:1];
  }
}

@end

int main(int argc, char *argv[]) {
  return NXApplicationMain(argc, argv, NXApplicationFeatureSignals, [Thermometer class]);
}
