#include <test/TestObject.h>
#include <test/test.h>

#define ITERATIONS 5000

static TestObject *shared = nil;
static TestObject *separate = nil;
static sys_waitgroup_t *wg = NULL;

static sys_atomic_t started;
static sys_atomic_t entered;
static sys_atomic_t other_entered;
static sys_atomic_t ready;
static volatile unsigned total = 0;

// Both threads call this, which starts once they've both got here. The loop makes
// it all but certain that they lose updates without a lock.
static void add(void) {
  sys_atomic_inc(&ready);
  while (sys_atomic_get(&ready) < 2) {
  }
  for (int i = 0; i < ITERATIONS; i++) {
    @synchronized(shared) {
      @synchronized(shared) {
        unsigned value = total;
        for (volatile int j = 0; j < 20; j++) {
        }
        total = value + 1;
      }
    }
  }
}

static void add_thread(void *arg) {
  (void)arg;
  add();
  sys_waitgroup_done(wg);
}

static void lock_thread(void *arg) {
  (void)arg;

  // Nobody has this one
  @synchronized(separate) {
    sys_atomic_set(&other_entered, 1);
  }

  // It's the other thread that has this, so it can't be unlocked by this one
  test_assert(objc_sync_exit(shared) != 0);
  sys_atomic_set(&started, 1);
  @synchronized(shared) {
    sys_atomic_set(&entered, 1);
  }
  sys_waitgroup_done(wg);
}

static void wait_for(sys_atomic_t *flag) {
  for (int i = 0; i < 2000 && sys_atomic_get(flag) == 0; i++) {
    sys_sleep_ms(1);
  }
  test_assert(sys_atomic_get(flag) != 0);
}

test_main(0) {
  if (sys_thread_numcores() < 2) {
    return;
  }
  shared = [[TestObject alloc] init];
  separate = [[TestObject alloc] init];
  wg = sys_waitgroup_init();
  test_assert(shared != nil && separate != nil && wg != NULL);

  // A thread waits for an object that's locked, but not for any other
  test_assert(sys_waitgroup_add(wg, 1));
  @synchronized(shared) {
    test_assert(sys_thread_create(lock_thread, NULL));
    wait_for(&other_entered);
    wait_for(&started);
    sys_sleep_ms(100);
    test_assert(sys_atomic_get(&entered) == 0);

    // It's still locked after being locked and unlocked again
    @synchronized(shared) {
    }
    sys_sleep_ms(100);
    test_assert(sys_atomic_get(&entered) == 0);
  }
  wait_for(&entered);
  sys_waitgroup_wait(wg);
  sys_sleep_ms(50); // so that the thread ends

  // Two threads don't lose any updates
  test_assert(sys_waitgroup_add(wg, 1));
  test_assert(sys_thread_create(add_thread, NULL));
  add();
  sys_waitgroup_wait(wg);
  test_assert(total == 2 * ITERATIONS);

  sys_waitgroup_deinit(wg);
  [separate free];
  [shared free];
}
