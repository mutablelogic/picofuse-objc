#include <Foundation/Foundation.h>
#include <test/test.h>

typedef struct {
  long values[8];
} large_t;

// What a thread writes is seen by the test once it's counted
static sys_atomic_t runs;
static sys_atomic_t deallocated;
static sys_atomic_t proceed;
static sys_atomic_t core, had_pool, could_run, as_expected;
static id expected = nil;

static void ran(void) {
  __atomic_thread_fence(__ATOMIC_RELEASE);
  sys_atomic_inc(&runs);
}

@interface Worker : NXObject
- (void)work;
- (void)wait;
- (int)result;
- (double)number;
- (large_t)large;
- (void)take:(id)object;
- (void)takeNumber:(int)number;
- (void)takePointer:(id *)pointer;
- (void)take:(id)object and:(id)other;
+ (void)work;
@end

@implementation Worker
- (void)work {
  sys_atomic_set(&core, [NXThread coreNumber]);
  sys_atomic_set(&had_pool, [NXAutoreleasePool currentPool] != nil);
  [[[NXObject alloc] init] autorelease];
  ran();
}
- (void)wait {
  sys_atomic_set(&could_run, [NXThread run:@selector(work)
                                    target:[Worker class]]);
  ran();
  while (sys_atomic_get(&proceed) == 0) {
    [NXThread sleepForDuration:NXMillisecond];
  }
}
- (int)result {
  ran();
  return 100;
}
- (double)number {
  ran();
  return 0.5;
}
- (large_t)large {
  large_t large = {{0}};
  test_assert(NO);
  return large;
}
- (void)take:(id)object {
  sys_atomic_set(&as_expected, object == expected);
  ran();
}
- (void)takeNumber:(int)number {
  (void)number;
  test_assert(NO);
}
- (void)takePointer:(id *)pointer {
  (void)pointer;
  test_assert(NO);
}
- (void)take:(id)object and:(id)other {
  (void)object;
  (void)other;
  test_assert(NO);
}
+ (void)work {
  ran();
}
- (void)dealloc {
  sys_atomic_inc(&deallocated);
  [super dealloc];
}
@end

// Wait until a count is reached, and reset it
static void wait_for(sys_atomic_t *value, uint32_t count) {
  for (int i = 0; i < 500 && sys_atomic_get(value) < count; i++) {
    [NXThread sleepForDuration:10 * NXMillisecond];
  }
  test_assert(sys_atomic_get(value) == count);
  __atomic_thread_fence(__ATOMIC_ACQUIRE);
  sys_atomic_set(value, 0);
}

// Run a thread. On a Pico, that can't be done until the last has ended, which is
// after anything here can tell.
#define RUN(call)                                                              \
  do {                                                                         \
    BOOL _started = NO;                                                        \
    for (int _i = 0; _i < 500 && !_started; _i++) {                            \
      _started = (call);                                                       \
      if (!_started) {                                                         \
        [NXThread sleepForDuration:10 * NXMillisecond];                        \
      }                                                                        \
    }                                                                          \
    test_assert(_started);                                                     \
  } while (0)

// Release an object which the thread still has, and wait for it to be deallocated,
// which is when the thread releases it
static void release_last(id object) {
  [(NXObject *)object release];
  wait_for(&deallocated, 1);
}

test_main(0) {
  // Sleeping
  NXDuration start = NXDurationTimestamp();
  [NXThread sleepForDuration:0];
  [NXThread sleepForDuration:-NXHour];
  test_assert(NXDurationTimestamp() - start < NXSecond);
  [NXThread sleepForDuration:100 * NXMillisecond];
  test_assert(NXDurationTimestamp() - start >= 95 * NXMillisecond);

  // Cores
  test_assert([NXThread numberOfCores] >= 1);
  test_assert([NXThread coreNumber] < [NXThread numberOfCores]);

  // The thread has a pool, and the target is released once the method returns
  Worker *worker = [[Worker alloc] init];
  RUN([NXThread run:@selector(work) target:worker]);
  wait_for(&runs, 1);
  release_last(worker);
  test_assert(sys_atomic_get(&had_pool));
  test_assert([NXAutoreleasePool currentPool] == nil);
#ifdef SYSTEM_NAME_PICO
  test_assert(sys_atomic_get(&core) == 1);
#endif

  // A class, and methods which return something
  RUN([NXThread run:@selector(work) target:[Worker class]]);
  wait_for(&runs, 1);
  worker = [[Worker alloc] init];
  RUN([NXThread run:@selector(result) target:worker]);
  wait_for(&runs, 1);
  RUN([NXThread run:@selector(number) target:worker]);
  wait_for(&runs, 1);
  release_last(worker);

  // The argument is released once the method returns, as is the target
  worker = [[Worker alloc] init];
  Worker *argument = [[Worker alloc] init];
  expected = argument;
  RUN([NXThread run:@selector(take:) target:worker argument:argument]);
  wait_for(&runs, 1);
  test_assert(sys_atomic_get(&as_expected));
  release_last(argument);

  // It can be nil, or an object which isn't an NXObject
  expected = nil;
  RUN([NXThread run:@selector(take:) target:worker argument:nil]);
  wait_for(&runs, 1);
  test_assert(sys_atomic_get(&as_expected));
  expected = @"string";
  RUN([NXThread run:@selector(take:) target:worker argument:expected]);
  wait_for(&runs, 1);
  test_assert(sys_atomic_get(&as_expected));
  release_last(worker);

  // Methods which can't be run. The target and argument aren't kept.
  worker = [[Worker alloc] init];
  argument = [[Worker alloc] init];
  test_assert(![NXThread run:@selector(cStr) target:worker]);
  test_assert(![NXThread run:@selector(work) target:nil]);
  test_assert(![NXThread run:NULL target:worker]);
  test_assert(![NXThread run:@selector(large) target:worker]);
  test_assert(![NXThread run:@selector(work) target:worker core:255]);
  test_assert(![NXThread run:@selector(take:) target:worker]);
  test_assert(![NXThread run:@selector(work) target:worker argument:argument]);
  test_assert(![NXThread run:@selector(takeNumber:)
                      target:worker
                    argument:argument]);
  test_assert(![NXThread run:@selector(takePointer:)
                      target:worker
                    argument:argument]);
  test_assert(![NXThread run:@selector(take:and:)
                      target:worker
                    argument:argument]);
  test_assert(![NXThread run:@selector(take:)
                      target:worker
                    argument:argument
                        core:255]);
  test_assert(sys_atomic_get(&runs) == 0);
  release_last(argument);
  release_last(worker);

  // On a core
  worker = [[Worker alloc] init];
#ifdef SYSTEM_NAME_PICO
  test_assert(![NXThread run:@selector(work) target:worker core:0]);
  sys_atomic_set(&core, 0);
  RUN([NXThread run:@selector(work) target:worker core:1]);
  wait_for(&runs, 1);
  test_assert(sys_atomic_get(&core) == 1);
  expected = worker;
  RUN([NXThread run:@selector(take:) target:worker argument:worker core:1]);
  wait_for(&runs, 1);
  test_assert(sys_atomic_get(&as_expected));

  // Nothing else can be run until the thread has ended, or from that thread
  sys_atomic_set(&could_run, 1);
  RUN([NXThread run:@selector(wait) target:worker]);
  wait_for(&runs, 1);
  test_assert(!sys_atomic_get(&could_run));
  test_assert(![NXThread run:@selector(work) target:worker]);
  sys_atomic_set(&proceed, 1);
  RUN([NXThread run:@selector(work) target:worker]);
  wait_for(&runs, 1);
#else
  if ([NXThread run:@selector(work) target:worker core:0]) {
    wait_for(&runs, 1);
    test_assert(sys_atomic_get(&core) == 0);
  }
#endif
  release_last(worker);

  // The last thread has only to end
  [NXThread sleepForDuration:100 * NXMillisecond];
}
