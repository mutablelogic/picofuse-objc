// Locks, conditions, wait groups and atomics, across threads
#include <Foundation/Foundation.h>
#include <test/test.h>

// A Pico has one more thread, on core 1
#if defined(SYSTEM_NAME_PICO)
#define WORKERS 1
#else
#define WORKERS 4
#endif
#define TIMES 20000

static NXLock *lock;
static NXCondition *condition;
static NXWaitGroup *group;
static NXAtomic *atomic;
static volatile uint32_t counted = 0; // only changed under the lock
static BOOL ready = NO, replied = NO;  // only changed under the condition

@interface Worker : NXObject
@end

@implementation Worker
+ (void)countWithLock {
  for (int i = 0; i < TIMES; i++) {
    [lock lock];
    counted = counted + 1;
    [lock unlock];
  }
  [group done];
}
+ (void)countWithAtomic {
  for (int i = 0; i < TIMES; i++) {
    [atomic increment];
  }
  [group done];
}
+ (void)countWithSwap {
  for (int i = 0; i < TIMES; i++) {
    uint32_t value;
    do {
      value = [atomic unsignedInt32Value];
    } while (![atomic compareAndSwap:value with:value + 1]);
  }
  [group done];
}
+ (void)reply {
  [condition lock];
  while (!ready) {
    [condition wait];
  }
  replied = YES;
  [condition signal];
  [condition unlock];
}
@end

// Starts a thread, waiting for one to be free, as on a Pico the last may still be
// finishing
static void start(SEL selector) {
  for (int tries = 0; ![NXThread run:selector target:[Worker class]]; tries++) {
    test_assert(tries < 1000);
    [NXThread sleepForDuration:NXMillisecond];
  }
}

static void locks(void) {
  lock = [[NXLock alloc] init];
  test_assert(lock != nil);
  test_assert([lock tryLock]);
  test_assert(![lock tryLock]); // not recursive
  [lock unlock];

  // Threads which count under the lock, and the one which waits for them
  group = [[NXWaitGroup alloc] init];
  [group add:WORKERS];
  for (int i = 0; i < WORKERS; i++) {
    start(@selector(countWithLock));
  }
  [group wait];
  test_assert(counted == WORKERS * TIMES);
  [group wait]; // already zero
  [group release];
  [lock release];
}

static void atomics(void) {
  atomic = [[NXAtomic alloc] init];
  test_assert([atomic unsignedInt32Value] == 0);
  group = [[NXWaitGroup alloc] init];
  [group add:WORKERS];
  for (int i = 0; i < WORKERS; i++) {
    start(@selector(countWithAtomic));
  }
  [group wait];
  test_assert([atomic unsignedInt32Value] == WORKERS * TIMES);
  [group release];

  // Counting with compare-and-swap
  [atomic setUnsignedInt32Value:0];
  group = [[NXWaitGroup alloc] init];
  [group add:WORKERS];
  for (int i = 0; i < WORKERS; i++) {
    start(@selector(countWithSwap));
  }
  [group wait];
  test_assert([atomic unsignedInt32Value] == WORKERS * TIMES);
  [group release];
  test_assert(![atomic compareAndSwap:0 with:1]);
  test_assert([atomic compareAndSwap:WORKERS * TIMES with:7]);
  test_assert([atomic unsignedInt32Value] == 7);

  // Each operation, and wrapping around
  [atomic setUnsignedInt32Value:0];
  test_assert([atomic decrement] == UINT32_MAX);
  test_assert([atomic increment] == 0);
  [atomic setBits:0x5];
  [atomic setBits:0x9];
  test_assert([atomic unsignedInt32Value] == 0xD);
  [atomic clearBits:0x4];
  test_assert([atomic unsignedInt32Value] == 0x9);
  test_assert_strequal([[atomic description] cStr], "9");
  test_assert([[NXAtomic atomicWithUnsignedInt32:42] unsignedInt32Value] == 42);
  [atomic release];
}

static void conditions(void) {
  condition = [[NXCondition alloc] init];
  test_assert(condition != nil);

  // Another thread waits until it's ready, then replies
  start(@selector(reply));
  [condition lock];
  ready = YES;
  [condition signal];
  while (!replied) {
    [condition wait];
  }
  [condition unlock];

  // No signal: it waits for at least the duration, but not for ever
  [condition lock];
  NXDate *before = [NXDate date];
  test_assert(![condition waitForDuration:20 * NXMillisecond]);
  NXDuration waited = [[NXDate date] durationSinceDate:before];
  test_assert(waited >= 19 * NXMillisecond && waited < NXSecond);
  test_assert(![condition waitForDuration:0]);
  test_assert(![condition waitForDuration:-NXSecond]);
  [condition unlock];

  // Signalling with no one waiting does nothing
  [condition signal];
  [condition broadcast];
  [condition release];
}

// Takes every one of a kind until there are none left, then gives them back
static void pool(Class class) {
  id objects[64];
  size_t n = 0;
  while (n < 64 && (objects[n] = [[class alloc] init]) != nil) {
    n++;
  }
  test_assert(n > 0 && n < 64);
  while (n > 0) {
    [objects[--n] release];
  }
  id object = [[class alloc] init];
  test_assert(object != nil);
  [object release];
}

test_main(0) {
  NXAutoreleasePool *autorelease = [[NXAutoreleasePool alloc] init];
  locks();
  atomics();
  conditions();
  pool([NXLock class]);
  pool([NXCondition class]);
  pool([NXWaitGroup class]);
  [autorelease release];
}
