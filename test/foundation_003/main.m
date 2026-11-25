#include <Foundation/Foundation.h>
#include <test/test.h>

#define ITERATIONS 3000

static NXObject *shared = nil;
static sys_waitgroup_t *wg = NULL;
static sys_atomic_t ready;
static sys_atomic_t deallocated;

@interface Thing : NXObject
@end

@implementation Thing
- (void)dealloc {
  sys_atomic_inc(&deallocated);
  [super dealloc];
}
@end

// Both threads call this, which starts once they've both got here
static void work(void) {
  sys_atomic_inc(&ready);
  while (sys_atomic_get(&ready) < 2) {
  }
  for (int i = 0; i < ITERATIONS; i++) {
    Thing *thing = [[Thing alloc] init];
    test_assert(thing != nil);
    [shared retain];
    [thing retain];
    [thing release];
    [shared release];
    [thing release];
  }
}

static void thread(void *arg) {
  (void)arg;
  work();
  sys_waitgroup_done(wg);
}

// Two threads allocate, retain and release at the same time
static void contend(void) {
  shared = [[Thing alloc] init];
  wg = sys_waitgroup_init();
  test_assert(shared != nil && wg != NULL);
  sys_atomic_set(&ready, 0);
  sys_atomic_set(&deallocated, 0);

  test_assert(sys_waitgroup_add(wg, 1));
  test_assert(sys_thread_create(thread, NULL));
  work();
  sys_waitgroup_wait(wg);
  sys_sleep_ms(50); // so that the thread ends

  // There's only the first reference left to the shared object
  test_assert(sys_atomic_get(&deallocated) == 2 * ITERATIONS);
  [shared release];
  test_assert(sys_atomic_get(&deallocated) == 2 * ITERATIONS + 1);
  sys_waitgroup_deinit(wg);
}

static NXZone *counted = nil;
static sys_atomic_t finished;

// There's always at least one block allocated in the zone, but by turns in each of
// its two arenas
static void alternate_thread(void *arg) {
  void *block = arg;
  for (int i = 0; i < 5 * ITERATIONS; i++) {
    void *next = [counted allocWithSize:200];
    test_assert(next != NULL);
    [counted free:block];
    block = next;
  }
  sys_atomic_set(&finished, 1);
  [counted free:block];
  sys_waitgroup_done(wg);
}

// Statistics are those of the zone at some moment
static void statistics(void) {
  counted = [NXZone zoneWithSize:256];
  wg = sys_waitgroup_init();
  test_assert(counted != nil && wg != NULL);
  void *block = [counted allocWithSize:200];
  test_assert(block != NULL);

  test_assert(sys_waitgroup_add(wg, 1));
  test_assert(sys_thread_create(alternate_thread, block));
  while (sys_atomic_get(&finished) == 0) {
    size_t count = [counted count];
    size_t used = [counted bytesUsed];
    if (sys_atomic_get(&finished) == 0) {
      test_assert(count == 1 || count == 2);
      test_assert(used == 200 || used == 400);
    }
  }
  sys_waitgroup_wait(wg);
  sys_sleep_ms(50); // so that the thread ends
  [counted release];
  sys_waitgroup_deinit(wg);
}

test_main(0) {
  if (sys_thread_numcores() < 2) {
    return;
  }

  contend();

  NXZone *zone = [NXZone zoneWithSize:1024];
  test_assert(zone != nil);
  contend();
  test_assert([zone count] == 0);
  [zone release];

  statistics();
}
