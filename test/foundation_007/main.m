#include <Foundation/Foundation.h>
#include <test/test.h>

static sys_atomic_t runs;
static sys_atomic_t class_runs;
static sys_atomic_t deallocated;
static sys_atomic_t proceed;
static volatile uint8_t core;
static id volatile taken;
static volatile BOOL had_pool, could_run;

@interface Worker : NXObject
- (void)work;
- (void)wait;
- (int)result;
- (void)take:(id)object;
- (void)take:(id)object and:(id)other;
+ (void)work;
@end

@implementation Worker
- (void)work {
  core = [NXThread coreNumber];
  had_pool = [NXAutoreleasePool currentPool] != nil;
  [[[NXObject alloc] init] autorelease];
  sys_atomic_inc(&runs);
}
- (void)wait {
  could_run = [NXThread run:@selector(work) target:[Worker class] core:0];
  sys_atomic_inc(&runs);
  while (sys_atomic_get(&proceed) == 0) {
    [NXThread sleepForDuration:NXMillisecond];
  }
}
- (int)result {
  sys_atomic_inc(&runs);
  return 100;
}
- (void)take:(id)object {
  taken = object;
  sys_atomic_inc(&runs);
}
- (void)take:(id)object and:(id)other {
  (void)object;
  (void)other;
  test_assert(NO);
}
+ (void)work {
  sys_atomic_inc(&class_runs);
}
- (void)dealloc {
  sys_atomic_inc(&deallocated);
  [super dealloc];
}
@end

static void wait_for(sys_atomic_t *value, uint32_t count) {
  for (int i = 0; i < 200 && sys_atomic_get(value) < count; i++) {
    [NXThread sleepForDuration:10 * NXMillisecond];
  }
  test_assert(sys_atomic_get(value) == count);
}

// So that the last thread has ended
static void settle(void) { [NXThread sleepForDuration:50 * NXMillisecond]; }

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
  if ([NXThread numberOfCores] < 2) {
    return;
  }

  // The thread has a pool, and the target is released once the method returns
  Worker *worker = [[Worker alloc] init];
  test_assert([NXThread run:@selector(work) target:worker]);
  [worker release];
  wait_for(&deallocated, 1);
  settle();
  test_assert(sys_atomic_get(&runs) == 1 && had_pool);
  test_assert([NXAutoreleasePool currentPool] == nil);
#ifdef SYSTEM_NAME_PICO
  test_assert(core == 1);
#endif

  // A class, and a method which returns something
  test_assert([NXThread run:@selector(work) target:[Worker class]]);
  wait_for(&class_runs, 1);
  settle();
  worker = [[Worker alloc] init];
  test_assert([NXThread run:@selector(result) target:worker]);
  wait_for(&runs, 2);
  settle();

  // The target isn't kept if the thread can't be started
  test_assert(![NXThread run:@selector(cStr) target:worker]);
  test_assert(![NXThread run:@selector(work) target:nil]);
  test_assert(![NXThread run:NULL target:worker]);
  test_assert(![NXThread run:@selector(work) target:worker core:255]);
  test_assert(sys_atomic_get(&runs) == 2 && sys_atomic_get(&deallocated) == 1);
  [worker release];
  test_assert(sys_atomic_get(&deallocated) == 2);

  // The argument is released once the method returns, as is the target
  worker = [[Worker alloc] init];
  Worker *argument = [[Worker alloc] init];
  id expected = argument;
  test_assert([NXThread run:@selector(take:) target:worker argument:argument]);
  [argument release];
  wait_for(&deallocated, 3);
  settle();
  test_assert(taken == expected && sys_atomic_get(&runs) == 3);

  // It can be nil, or an object which isn't an NXObject
  test_assert([NXThread run:@selector(take:) target:worker argument:nil]);
  wait_for(&runs, 4);
  settle();
  test_assert(taken == nil);
  test_assert([NXThread run:@selector(take:) target:worker argument:@"string"]);
  wait_for(&runs, 5);
  settle();
  test_assert([(NXConstantString *)taken isEqual:@"string"]);

  // The method has to have the right number of arguments
  argument = [[Worker alloc] init];
  test_assert(![NXThread run:@selector(take:) target:worker]);
  test_assert(![NXThread run:@selector(work) target:worker argument:argument]);
  test_assert(![NXThread run:@selector(take:and:)
                      target:worker
                    argument:argument]);
  test_assert(![NXThread run:@selector(take:)
                      target:worker
                    argument:argument
                        core:255]);
  test_assert(sys_atomic_get(&runs) == 5 && sys_atomic_get(&deallocated) == 3);
  [argument release];
  [worker release];
  test_assert(sys_atomic_get(&deallocated) == 5);
  sys_atomic_set(&runs, 2);
  sys_atomic_set(&deallocated, 2);

  // On a core
  worker = [[Worker alloc] init];
#ifdef SYSTEM_NAME_PICO
  test_assert(![NXThread run:@selector(work) target:worker core:0]);
  test_assert([NXThread run:@selector(work) target:worker core:1]);
  wait_for(&runs, 3);
  settle();
  test_assert(core == 1);
  test_assert([NXThread run:@selector(take:)
                     target:worker
                   argument:worker
                       core:1]);
  wait_for(&runs, 4);
  settle();
  test_assert(taken == worker);

  // Nothing else can be run until the thread has ended, or from that thread
  could_run = YES;
  test_assert([NXThread run:@selector(wait) target:worker]);
  wait_for(&runs, 5);
  test_assert(![NXThread run:@selector(work) target:worker]);
  test_assert(!could_run);
  sys_atomic_set(&proceed, 1);
  settle();
  test_assert([NXThread run:@selector(work) target:worker]);
  wait_for(&runs, 6);
  settle();
#else
  if ([NXThread run:@selector(work) target:worker core:0]) {
    wait_for(&runs, 3);
    settle();
    test_assert(core == 0);
  }
#endif
  [worker release];
  wait_for(&deallocated, 3);
}
