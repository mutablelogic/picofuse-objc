// Prints "Hello world" when the application starts, then quits
#include <Application/Application.h>

@interface HelloWorld : NXObject <NXApplicationDelegate>
@end

@implementation HelloWorld

- (void)applicationDidStart:(NXApplication *)application watchdogReset:(BOOL)reset {
  (void)reset;
  NXLog(@"Hello world");
  [application terminateWithStatus:0];
}

@end

int main(int argc, char *argv[]) {
  return NXApplicationMain(argc, argv, NXApplicationFeatureNone, [HelloWorld class]);
}
