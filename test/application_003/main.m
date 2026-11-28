// NXApplicationMain: the command line, --help, a bad flag, a class which isn't a
// delegate, the features, and on a host, a signal which terminates it. On a Pico, it
// runs for longer than the watchdog's timeout, so the run loop has to feed it.
#include <Application/Application.h>
#include <string.h>
#include <test/test.h>
#if !defined(SYSTEM_NAME_PICO)
#include <signal.h>
#endif

#define FEATURES                                                                         \
  (NXApplicationFeatureMulticore | NXApplicationFeatureWatchdog |                        \
   NXApplicationFeatureSignals | NXApplicationFeatureStdioRTT)

@interface Controller : NXObject <NXApplicationDelegate>
@end

@implementation Controller
+ (NXArray *)commandLineFlags {
  return [NXArray arrayWithObjects:[NXArgument argumentWithName:@"verbose" short:@"v"],
                                   [NXArgument argumentWithName:@"count" short:@"n"
                                                        default:[NXNumber numberWithInt32:3]],
                                   // Has -h, so --help doesn't
                                   [NXArgument argumentWithName:@"host" short:@"h"
                                                        default:@"localhost"],
                                   nil];
}
- (void)applicationDidStart:(NXApplication *)application watchdogReset:(BOOL)reset {
  test_assert(!reset);
  sys_printf("[TEST] [INIT] %s\n", sys_env_name());
  test_assert(application == [NXApplication sharedApplication]);
  test_assert([application delegate] == self);
  test_assert([application workers] == 0); // multicore

  // The environment, and every flag's value but --help
  NXEnvironment *environment = [application environment];
  test_assert(environment != nil && [environment name] != nil);
  NXMap *flags = [application flags];
  test_assert(flags != nil && [flags count] == 3);
  test_assert([[flags objectForKey:@"host"] isEqual:@"localhost"]);
  test_assert([flags objectForKey:@"help"] == nil);
  test_assert(![[flags objectForKey:@"verbose"] boolValue]);
#if defined(SYSTEM_NAME_PICO)
  test_assert([[flags objectForKey:@"count"] int32Value] == 3);
  // Longer than the watchdog's timeout, which is about 8s
  test_assert([[NXTimer timerWithInterval:10 * NXSecond
                                  repeats:NO
                                   target:self
                                 selector:@selector(done:)] schedule]);
#else
  test_assert([[flags objectForKey:@"count"] int32Value] == 4);
  test_assert([[environment arguments] count] == 1);
  raise(SIGTERM); // terminates it with 128 + 15
#endif
}
- (void)done:(NXTimer *)timer {
  (void)timer;
  [[NXApplication sharedApplication] terminateWithStatus:5];
}
- (void)applicationWillTerminate:(NXApplication *)application signal:(int)signal {
  (void)application;
#if defined(SYSTEM_NAME_PICO)
  test_assert(signal == 0);
#else
  test_assert(signal == 15); // TERM
#endif
}
@end

// Not a delegate
@interface Other : NXObject
@end
@implementation Other
@end

int main(int argc, char *argv[]) {
  // The last argument says what's expected. A Pico has no command line, and main()
  // isn't given one.
#if defined(SYSTEM_NAME_PICO)
  const char *last = "";
#else
  const char *last = argc > 1 ? argv[argc - 1] : "";
#endif
  BOOL other = strcmp(last, "other") == 0;
  int expected;
  if (strcmp(last, "--help") == 0) {
    expected = 0;
  } else if (strcmp(last, "--count=abc") == 0) {
    expected = 2;
  } else if (other) {
    expected = 1;
  } else {
#if defined(SYSTEM_NAME_PICO)
    expected = 5;
#else
    expected = 128 + 15;
#endif
  }

  int status = NXApplicationMain(argc, argv, FEATURES, other ? [Other class] : [Controller class]);

  // Once it has finished, and only with the status expected, which is what a Pico's
  // test runner looks for. The system is still running.
  if (status != expected) {
    sys_printf("[PANIC] status %d, not %d\n", status, expected);
    return 1;
  }
  sys_printf("[TEST] [EXIT] %s\n", sys_env_name());
  sys_exit();
  return 0;
}
