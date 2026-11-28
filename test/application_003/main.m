// NXApplicationMain: the command line, --help, a bad flag, a class which isn't a
// delegate, the features, and on a host, a signal which terminates it
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
                                   nil];
}
- (void)applicationDidStart:(NXApplication *)application {
  sys_printf("[TEST] [INIT] %s\n", sys_env_name());
  test_assert(application == [NXApplication sharedApplication]);
  test_assert([application delegate] == self);
  test_assert([application workers] == 0); // multicore

  // The environment, and every flag's value but --help
  NXEnvironment *environment = [application environment];
  test_assert(environment != nil && [environment name] != nil);
  NXMap *flags = [application flags];
  test_assert(flags != nil && [flags count] == 2);
  test_assert([flags objectForKey:@"help"] == nil);
  test_assert(![[flags objectForKey:@"verbose"] boolValue]);
#if defined(SYSTEM_NAME_PICO)
  test_assert([[flags objectForKey:@"count"] int32Value] == 3);
  [application terminateWithStatus:5];
#else
  test_assert([[flags objectForKey:@"count"] int32Value] == 4);
  test_assert([[environment arguments] count] == 1);
  raise(SIGTERM); // terminates it with 128 + 15
#endif
}
- (void)applicationWillTerminate:(NXApplication *)application {
  (void)application;
  sys_printf("[TEST] [EXIT] %s\n", sys_env_name());
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
  return status == expected ? 0 : 1;
}
