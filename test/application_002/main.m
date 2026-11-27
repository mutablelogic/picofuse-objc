// NXTimer, as an event source of the application: repeating and one-shot timers, timers
// scheduled before and while it runs, and invalidating them
#include <Application/Application.h>
#include <test/test.h>

@interface Ticker : NXObject <NXApplicationDelegate> {
@public
  NXAtomic *repeats;   // firings of the repeating timer
  NXAtomic *once;      // firings of the one-shot timer
  NXAtomic *never;     // firings of the timer invalidated before it fires
  NXAtomic *late;      // firings of the timer scheduled while running
  NXAtomic *posted;    // ordinary events, between the timers'
  NXTimer *repeating;
  NXTimer *oneShot;
  NXTimer *invalidated;
}
@end

@implementation Ticker
- (id)init {
  self = [super init];
  repeats = [NXAtomic new];
  once = [NXAtomic new];
  never = [NXAtomic new];
  late = [NXAtomic new];
  posted = [NXAtomic new];
  return self;
}
- (void)dealloc {
  [repeats release];
  [once release];
  [never release];
  [late release];
  [posted release];
  [super dealloc];
}
- (void)tick:(NXTimer *)timer {
  test_assert(timer == repeating && [timer isValid]);
  if ([repeats increment] == 5) {
    [timer invalidate];
    test_assert(![timer isValid]);
  }
}
- (void)once:(NXTimer *)timer {
  test_assert(timer == oneShot);
  [once increment];
}
- (void)never:(NXTimer *)timer {
  (void)timer;
  [never increment];
}
- (void)late:(NXTimer *)timer {
  (void)timer;
  [late increment];
}
- (void)event {
  [posted increment];
}
- (void)check:(NXTimer *)timer {
  (void)timer;
  [[[NXApplication sharedApplication] runLoop] perform:@selector(event) target:self];
  if ([repeats unsignedInt32Value] >= 5 && [once unsignedInt32Value] == 1 &&
      [late unsignedInt32Value] >= 2) {
    [timer invalidate];
    [[NXApplication sharedApplication] terminateWithStatus:4];
  }
}
- (void)applicationDidStart:(NXApplication *)application {
  (void)application;
  // Scheduled while it runs, which starts straight away
  NXTimer *timer = [NXTimer timerWithInterval:5 * NXMillisecond
                                      repeats:YES
                                       target:self
                                     selector:@selector(late:)];
  test_assert([timer schedule]);
  test_assert(![[NXApplication sharedApplication] attachEventSource:timer]); // already
  NXTimer *checker = [NXTimer timerWithInterval:20 * NXMillisecond
                                        repeats:YES
                                         target:self
                                       selector:@selector(check:)];
  test_assert([checker schedule]);
}
@end

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  Ticker *ticker = [Ticker new];
  NXApplication *application = [NXApplication sharedApplication];
  [application setDelegate:ticker];

  // Timers which can't be made
  test_assert([NXTimer timerWithInterval:0 repeats:NO target:ticker selector:@selector(once:)] ==
              nil);
  test_assert([NXTimer timerWithInterval:NXSecond repeats:NO target:ticker
                                selector:@selector(event)] == nil);
  test_assert([NXTimer timerWithInterval:NXSecond repeats:NO target:nil
                                selector:@selector(once:)] == nil);
  test_assert(![application attachEventSource:nil]);
  test_assert(![application attachEventSource:(id<NXEventSource>)ticker]);

  // Scheduled before it runs, which start when it does
  ticker->repeating = [NXTimer timerWithInterval:5 * NXMillisecond
                                         repeats:YES
                                          target:ticker
                                        selector:@selector(tick:)];
  ticker->oneShot = [NXTimer timerWithInterval:10 * NXMillisecond
                                       repeats:NO
                                        target:ticker
                                      selector:@selector(once:)];
  ticker->invalidated = [NXTimer timerWithInterval:5 * NXMillisecond
                                           repeats:YES
                                            target:ticker
                                          selector:@selector(never:)];
  test_assert([ticker->repeating schedule] && [ticker->oneShot schedule]);
  test_assert([ticker->invalidated schedule]);
  [ticker->invalidated invalidate];
  test_assert(![ticker->invalidated isValid] && ![ticker->invalidated schedule]);
  test_assert([ticker->repeating interval] == 5 * NXMillisecond && [ticker->repeating repeats]);

  // Firing by hand
  [ticker->oneShot fire];
  test_assert([ticker->once unsignedInt32Value] == 1);
  [ticker->once setUnsignedInt32Value:0];

  test_assert([NXApplication run] == 4);
  test_assert([ticker->repeats unsignedInt32Value] == 5);
  test_assert([ticker->once unsignedInt32Value] == 1 && ![ticker->oneShot isValid]);
  test_assert([ticker->never unsignedInt32Value] == 0);
  test_assert([ticker->late unsignedInt32Value] >= 2 && [ticker->posted unsignedInt32Value] > 0);

  // Again: the late timer is still attached and starts again, the others are done
  [ticker->late setUnsignedInt32Value:0];
  [ticker->repeats setUnsignedInt32Value:5];
  test_assert([NXApplication run] == 4);
  test_assert([ticker->late unsignedInt32Value] >= 2);
  test_assert([ticker->once unsignedInt32Value] == 1 && [ticker->never unsignedInt32Value] == 0);

  [application setDelegate:nil];
  [ticker release];
  [pool release];
}
