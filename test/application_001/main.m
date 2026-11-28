// NXRunLoop and NXApplication: events across workers, delegates, and shutting down
#include <Application/Application.h>
#include <test/test.h>

#define EVENTS 200

static NXAtomic *dispatched;  // events dispatched
static NXAtomic *deallocated; // events deallocated
static NXAtomic *started, *stopped;
static NXAtomic *ready;    // set at the end of runLoopDidStart:
static NXAtomic *finished; // events which have finished, slowly

// An event which counts itself, and shuts the run loop down when it's the last
@interface Counted : NXObject <NXEvent>
@end

@implementation Counted
- (void)dealloc {
  [deallocated increment];

  // It's released before its pool, so this has somewhere to go
  [[[NXObject alloc] init] autorelease];
  [super dealloc];
}
- (void)dispatch {
  // None is dispatched until the delegate is told the run loop started
  test_assert([ready unsignedInt32Value] == 1);
  uint32_t n = [dispatched increment];
  if (n == EVENTS) {
    [[NXRunLoop runningRunLoop] shutdownWithStatus:7];
  }

  // The last few are slow, so they're still running on other workers as it stops
  if (n > EVENTS - 4) {
    [NXThread sleepForDuration:20 * NXMillisecond];
  }
  [finished increment];
}
@end

// Fills a small queue, on one worker, so nothing is taken until it returns
@interface Filler : NXObject <NXRunLoopDelegate> {
@public
  int posted;
}
@end

@implementation Filler
- (void)runLoopDidStart:(NXRunLoop *)runLoop {
  [ready setUnsignedInt32Value:1];
  while ([runLoop post:[[[Counted alloc] init] autorelease]]) {
    posted++;
  }
  [runLoop shutdownWithStatus:5];
}
@end

// Posts the events when the run loop starts, and is sent messages by them
@interface Poster : NXObject <NXRunLoopDelegate, NXApplicationDelegate> {
@public
  int messages;
  id argument;
}
- (void)message;
- (void)messageWith:(id)object;
- (int)wrong:(int)value;
@end

@implementation Poster
- (void)runLoopDidStart:(NXRunLoop *)runLoop {
  [started increment];
  test_assert([runLoop isRunning] && [NXRunLoop runningRunLoop] == runLoop);
  // There's room for them all, as with one worker, none are taken until this returns
  for (int i = 0; i < EVENTS; i++) {
    Counted *event = [[Counted alloc] init];
    test_assert([runLoop post:event]);
    [event release];
  }

  // Other workers mustn't dispatch them yet
  [NXThread sleepForDuration:20 * NXMillisecond];
  [ready setUnsignedInt32Value:1];
}
- (void)runLoopWillStop:(NXRunLoop *)runLoop {
  // Every event has finished, on every worker
  test_assert([finished unsignedInt32Value] == EVENTS);
  [stopped increment];
  test_assert(![runLoop post:[[[Counted alloc] init] autorelease]]);
}
- (void)message {
  messages++;
}
- (void)messageWith:(id)object {
  argument = object;
  [[NXApplication sharedApplication] terminateWithStatus:3];
}
- (int)wrong:(int)value {
  return value;
}
- (void)applicationDidStart:(NXApplication *)application {
  [started increment];
  NXRunLoop *runLoop = [application runLoop];
  test_assert([runLoop perform:@selector(message) target:self]);
  test_assert([runLoop perform:@selector(messageWith:) target:self argument:@"done"]);
  test_assert(![runLoop perform:@selector(wrong:) target:self argument:@"x"]);
  test_assert(![runLoop perform:@selector(messageWith:) target:self]);
  test_assert(![runLoop perform:@selector(nothing) target:self]);
}
- (void)applicationWillTerminate:(NXApplication *)application {
  (void)application;
  [stopped increment];
}
@end

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  dispatched = [[NXAtomic alloc] init];
  deallocated = [[NXAtomic alloc] init];
  started = [[NXAtomic alloc] init];
  ready = [[NXAtomic alloc] init];
  finished = [[NXAtomic alloc] init];
  stopped = [[NXAtomic alloc] init];
  Poster *poster = [[Poster alloc] init];

  // Not running: nothing can be posted, and shutting down does nothing
  NXRunLoop *runLoop = [[NXRunLoop alloc] initWithCapacity:EVENTS];
  test_assert(![runLoop isRunning] && [NXRunLoop runningRunLoop] == nil);
  test_assert(![runLoop post:[[[Counted alloc] init] autorelease]]);
  [runLoop shutdownWithStatus:1];

  // Every event is dispatched and released, on every worker, and then it stops
  [runLoop setDelegate:poster];
  for (uint8_t workers = 0; workers <= 2; workers++) {
    [dispatched setUnsignedInt32Value:0];
    [deallocated setUnsignedInt32Value:0];
    [started setUnsignedInt32Value:0];
    [stopped setUnsignedInt32Value:0];
    [ready setUnsignedInt32Value:0];
    [finished setUnsignedInt32Value:0];
    test_assert([runLoop runWithWorkers:workers] == 7);
    test_assert([dispatched unsignedInt32Value] == EVENTS);
    test_assert([deallocated unsignedInt32Value] == EVENTS + 1); // and the one refused
    test_assert([started unsignedInt32Value] == 1 && [stopped unsignedInt32Value] == 1);
    test_assert(![runLoop isRunning] && [NXRunLoop runningRunLoop] == nil);
  }
  [runLoop release];

  // A full queue refuses events, and those in it are still dispatched
  Filler *filler = [[Filler alloc] init];
  runLoop = [[NXRunLoop alloc] initWithCapacity:4];
  [runLoop setDelegate:filler];
  [dispatched setUnsignedInt32Value:0];
  test_assert([runLoop runWithWorkers:1] == 5);
  test_assert(filler->posted == 4 && [dispatched unsignedInt32Value] == 4);
  [runLoop release];
  [filler release];

  // The application, with messages sent by its run loop
  NXApplication *application = [NXApplication sharedApplication];
  test_assert(application != nil && [NXApplication sharedApplication] == application);
  test_assert([application workers] == 1); // the default
  [application setDelegate:poster];
  [started setUnsignedInt32Value:0];
  [stopped setUnsignedInt32Value:0];
  test_assert([NXApplication run] == 3);
  test_assert(poster->messages == 1 && [poster->argument isEqual:@"done"]);
  test_assert([started unsignedInt32Value] == 1 && [stopped unsignedInt32Value] == 1);

  // And again, on every core
  [application setWorkers:0];
  test_assert([application run] == 3 && poster->messages == 2);

  [poster release];
  [pool release];
}
