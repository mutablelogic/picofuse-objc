// NXAnalogInput: the temperature sensor and an ADC channel, attached to the
// application, read, and sending their messages when their readings change. Where
// there's no ADC, as on a Mac or Linux, they don't attach.
#include <Application/Application.h>
#include <picofuse/hw.h>
#include <test/test.h>

@interface Reader : NXObject <NXApplicationDelegate> {
@public
  NXAnalogInput *temperature;
  NXAnalogInput *channel;
  NXAtomic *temperatures; // messages from the temperature sensor
  NXAtomic *readings;     // messages from the channel
}
@end

@implementation Reader
- (id)init {
  self = [super init];
  temperatures = [NXAtomic new];
  readings = [NXAtomic new];
  return self;
}
- (void)dealloc {
  [temperatures release];
  [readings release];
  [super dealloc];
}
- (void)changed:(NXAnalogInput *)input {
  if (input == temperature) {
    [temperatures increment];
  } else {
    test_assert(input == channel);
    [readings increment];
  }
}
- (void)event {
}
- (void)done:(NXTimer *)timer {
  (void)timer;
  if ([temperature isAttached]) {
    // The chip is somewhere between freezing and too hot to touch
    float celsius = [temperature floatValue];
    float volts = [channel floatValue];
    sys_printf("[application_006] %.1fC, channel 0 %.2fV, %u and %u messages\n",
               (double)celsius, (double)volts, [temperatures unsignedInt32Value],
               [readings unsignedInt32Value]);
    test_assert(celsius > 0 && celsius < 60);
    test_assert(volts >= 0 && volts < 3.5f);
    test_assert([temperatures unsignedInt32Value] > 0 && [readings unsignedInt32Value] > 0);
  }
  [[NXApplication sharedApplication] terminateWithStatus:0];
}
- (void)applicationDidStart:(NXApplication *)application watchdogReset:(BOOL)reset {
  (void)reset;
  BOOL adc = [temperature isAttached];
  sys_printf("[application_006] %s ADC\n", adc ? "with" : "without");
  if (!adc) {
    test_assert(![channel isAttached] && [temperature floatValue] == 0);
    [application terminateWithStatus:0];
    return;
  }
  test_assert([channel isAttached]);
  test_assert([[NXTimer timerWithInterval:2 * NXSecond
                                  repeats:NO
                                   target:self
                                 selector:@selector(done:)] schedule]);
}
@end

test_main(0) {
  hw_init(); // as NXApplicationMain does
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  Reader *reader = [Reader new];

  // Inputs which can't be made
  test_assert([NXAnalogInput inputWithChannel:0 interval:0 target:reader
                                     selector:@selector(changed:)] == nil);
  test_assert([NXAnalogInput inputWithChannel:0 interval:NXSecond target:nil
                                     selector:@selector(changed:)] == nil);
  test_assert([NXAnalogInput temperatureWithInterval:NXSecond target:reader
                                            selector:@selector(event)] == nil);

  // Read often, so they change in the time it runs
  reader->temperature = [NXAnalogInput temperatureWithInterval:50 * NXMillisecond
                                                        target:reader
                                                      selector:@selector(changed:)];
  reader->channel = [NXAnalogInput inputWithChannel:0
                                           interval:50 * NXMillisecond
                                             target:reader
                                           selector:@selector(changed:)];
  test_assert(reader->temperature != nil && reader->channel != nil);
  test_assert([reader->temperature isTemperature] && ![reader->channel isTemperature]);
  test_assert([reader->channel channel] == 0 && [reader->channel interval] == 50 * NXMillisecond);
  test_assert(![reader->channel isAttached] && [reader->channel floatValue] == 0);

  NXApplication *application = [NXApplication sharedApplication];
  test_assert([application attachEventSource:reader->temperature]);
  test_assert([application attachEventSource:reader->channel]);
  [application setDelegate:reader];
  test_assert([application run] == 0);
  test_assert(![reader->temperature isAttached] && ![reader->channel isAttached]);

  [application setDelegate:nil];
  [reader release];
  [pool release];
  hw_exit();
}
