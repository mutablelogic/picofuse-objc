// NXDigitalOutput and NXDigitalInput: an output driven high and low, and inputs pulled
// up and down, attached to the application. Where there's no GPIO, as on a Mac or in a
// container, there are no outputs, and inputs don't attach. If the output is wired to
// the pulled-up input, such as GPIO17 to GPIO27 on a Raspberry Pi, the input sends its
// message each time the output changes.
#include <Application/Application.h>
#include <picofuse/hw.h>
#include <test/test.h>

#if defined(SYSTEM_NAME_PICO)
#define OUTPUT_PIN 2
#define UP_PIN 3
#define DOWN_PIN 4
#else
#define OUTPUT_PIN 17
#define UP_PIN 27
#define DOWN_PIN 22
#endif

#define CHANGES 6

@interface Watcher : NXObject <NXApplicationDelegate> {
@public
  NXDigitalOutput *output;
  NXDigitalInput *up;
  NXDigitalInput *down;
  BOOL gpio;
  BOOL wired;
  NXAtomic *changes; // messages from the wired input
  NXAtomic *toggles; // changes of the output
}
@end

@implementation Watcher
- (id)init {
  self = [super init];
  changes = [NXAtomic new];
  toggles = [NXAtomic new];
  return self;
}
- (void)dealloc {
  [changes release];
  [toggles release];
  [super dealloc];
}
- (void)changed:(NXDigitalInput *)input {
  // Only the wired input is driven, and it follows the output
  test_assert(wired && input == up);
  test_assert([input boolValue] == [output boolValue]);
  [changes increment];
}
- (void)event {
}
- (void)toggle:(NXTimer *)timer {
  // The message from driving it low as it started is dispatched once that returned,
  // which is before this first tick
  if ([toggles unsignedInt32Value] == 0) {
    [changes setUnsignedInt32Value:0];
  }
  if ([toggles unsignedInt32Value] == CHANGES) {
    // Every change has been seen, which is after the debounce
    test_assert([changes unsignedInt32Value] == CHANGES);
    [timer invalidate];
    [[NXApplication sharedApplication] terminateWithStatus:0];
    return;
  }
  [output toggle];
  [toggles increment];
}
- (void)applicationDidStart:(NXApplication *)application watchdogReset:(BOOL)reset {
  (void)reset;
  if (!gpio) {
    test_assert(![up isAttached] && ![up boolValue]);
    [application terminateWithStatus:0];
    return;
  }
  test_assert([up isAttached] && [down isAttached]);
  test_assert([up pin] == UP_PIN && [up bank] == 0 && [up pull] == NXPinPullUp);
  test_assert(![down boolValue]);

  // The output drives the pulled-up input low, if they're wired
  [output setBoolValue:NO];
  sys_sleep_ms(50);
  wired = ![up boolValue];
  sys_printf("[application_005] output %s wired to the pulled-up input\n",
             wired ? "is" : "isn't");
  if (!wired) {
    [application terminateWithStatus:0];
    return;
  }

  // Toggled less often than it's debounced, and each change is a message
  test_assert([[NXTimer timerWithInterval:100 * NXMillisecond
                                  repeats:YES
                                   target:self
                                 selector:@selector(toggle:)] schedule]);
}
@end

test_main(0) {
  hw_init(); // as NXApplicationMain does
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  Watcher *watcher = [Watcher new];

  // An output, which starts low
  NXDigitalOutput *output = [NXDigitalOutput outputWithPin:OUTPUT_PIN];
  watcher->output = output;
  watcher->gpio = output != nil;
  sys_printf("[application_005] %s GPIO\n", watcher->gpio ? "with" : "without");
  if (watcher->gpio) {
    test_assert([output pin] == OUTPUT_PIN && ![output boolValue]);
    [output setBoolValue:YES];
    test_assert([output boolValue]);
    [output toggle];
    test_assert(![output boolValue]);
    [output toggle];
    test_assert([output boolValue]);
    test_assert([[output description] containsString:@"high"]);
  }

  // Inputs which can't be made
  test_assert([NXDigitalInput inputWithPin:UP_PIN pull:NXPinPullUp target:nil
                                  selector:@selector(changed:)] == nil);
  test_assert([NXDigitalInput inputWithPin:UP_PIN pull:NXPinPullUp target:watcher
                                  selector:@selector(event)] == nil);
  test_assert([NXDigitalInput inputWithPin:UP_PIN pull:(NXPinPull)7 target:watcher
                                  selector:@selector(changed:)] == nil);

  // Inputs, which aren't read until they're attached
  watcher->up = [NXDigitalInput inputWithPin:UP_PIN pull:NXPinPullUp target:watcher
                                    selector:@selector(changed:)];
  watcher->down = [NXDigitalInput inputWithPin:DOWN_PIN pull:NXPinPullDown target:watcher
                                      selector:@selector(changed:)];
  test_assert(watcher->up != nil && watcher->down != nil);
  test_assert(![watcher->up isAttached] && ![watcher->up boolValue]);
  NXApplication *application = [NXApplication sharedApplication];
  test_assert([application attachEventSource:watcher->up]);
  test_assert([application attachEventSource:watcher->down]);

  [application setDelegate:watcher];
  test_assert([application run] == 0);
  test_assert(![watcher->up isAttached] && ![watcher->down isAttached]);

  [application setDelegate:nil];
  [watcher release];
  [pool release];
  hw_exit();
}
