// Prints the temperature sensor's reading every --interval, which on a Pico, with no
// command line, is its default, until it's interrupted
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

- (void)changed:(NXAnalogInput *)sensor {
  (void)sensor;
}

- (void)print:(NXTimer *)timer {
  (void)timer;
  NXLog(@"%.1fC", (double)[_sensor floatValue]);
}

- (void)applicationDidStart:(NXApplication *)application watchdogReset:(BOOL)reset {
  (void)reset;
  NXDuration interval = [[[application flags] objectForKey:@"interval"] int64Value];
  if (interval <= 0) {
    NXLog(@"The interval has to be more than zero");
    [application terminateWithStatus:2];
    return;
  }

  // The sensor, which can only be read while it's attached
  _sensor = [[NXAnalogInput temperatureWithInterval:interval
                                             target:self
                                           selector:@selector(changed:)] retain];
  if (![application attachEventSource:_sensor]) {
    NXLog(@"There's no temperature sensor");
    [application terminateWithStatus:1];
    return;
  }

  // Printed now, and then every interval
  [self print:nil];
  [[NXTimer timerWithInterval:interval
                      repeats:YES
                       target:self
                     selector:@selector(print:)] schedule];
}

@end

int main(int argc, char *argv[]) {
  return NXApplicationMain(argc, argv, NXApplicationFeatureSignals, [Thermometer class]);
}
