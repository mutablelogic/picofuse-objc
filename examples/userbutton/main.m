// Prints whether the board's user button is pressed whenever it changes, until it's
// interrupted
#include <Application/Application.h>

@interface Button : NXObject <NXApplicationDelegate>
@end

@implementation Button

// The button connects its pin to ground, so it's low while it's pressed
- (void)changed:(NXDigitalInput *)button {
  NXLog(@"%@", [button boolValue] ? @"released" : @"pressed");
}

- (void)applicationDidStart:(NXApplication *)application watchdogReset:(BOOL)reset {
  (void)reset;
  NXDigitalInput *button = [NXDigitalInput userButtonWithTarget:self
                                                       selector:@selector(changed:)];
  if (button == nil || ![application attachEventSource:button]) {
    NXLog(@"There's no user button");
    [application terminateWithStatus:1];
    return;
  }
  NXLog(@"Press the user button");
}

@end

int main(int argc, char *argv[]) {
  return NXApplicationMain(argc, argv, NXApplicationFeatureSignals, [Button class]);
}
