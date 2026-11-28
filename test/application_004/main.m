// The watchdog restarts a device whose run loop stops: the first start blocks worker 0,
// so it isn't fed, and the start after the restart is told so.
#include <Application/Application.h>
#include <test/test.h>

@interface Controller : NXObject <NXApplicationDelegate>
@end

@implementation Controller
- (void)applicationDidStart:(NXApplication *)application watchdogReset:(BOOL)reset {
  if (!reset) {
    sys_printf("[TEST] [INIT] %s\n", sys_env_name());
    for (;;) {
      sys_sleep_ms(100); // worker 0 never returns, so the watchdog isn't fed
    }
  }
  [application terminateWithStatus:3];
}
@end

int main(int argc, char *argv[]) {
  int status = NXApplicationMain(
      argc, argv, NXApplicationFeatureWatchdog | NXApplicationFeatureStdioRTT, [Controller class]);

  // Once it has finished, with the status from after the restart
  if (status != 3) {
    sys_printf("[PANIC] status %d, not 3\n", status);
    return 1;
  }
  sys_printf("[TEST] [EXIT] %s\n", sys_env_name());
  return 0;
}
