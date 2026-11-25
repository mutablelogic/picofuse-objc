#include <Foundation/Foundation.h>
#include <test/test.h>

#define ITERATIONS 500
#define OBJECTS 20

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
    NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
    test_assert([NXAutoreleasePool currentPool] == pool);
    for (int j = 0; j < OBJECTS; j++) {
      [[[Thing alloc] init] autorelease];
    }
    test_assert([pool count] == OBJECTS);
    [pool release];
  }
}

static void thread(void *arg) {
  // The other thread has a pool, but this one doesn't
  test_assert([NXAutoreleasePool currentPool] == nil);
  work();
  test_assert([NXAutoreleasePool currentPool] == nil);
  (void)arg;
  sys_waitgroup_done(wg);
}

test_main(0) {
  if (sys_thread_numcores() < 2) {
    return;
  }
  wg = sys_waitgroup_init();
  test_assert(wg != NULL);

  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  [[[Thing alloc] init] autorelease];
  test_assert(sys_waitgroup_add(wg, 1));
  test_assert(sys_thread_create(thread, NULL));
  work();
  sys_waitgroup_wait(wg);
  sys_sleep_ms(50); // so that the thread ends

  test_assert([NXAutoreleasePool currentPool] == pool && [pool count] == 1);
  test_assert(sys_atomic_get(&deallocated) == 2 * ITERATIONS * OBJECTS);
  [pool release];
  test_assert(sys_atomic_get(&deallocated) == 2 * ITERATIONS * OBJECTS + 1);
  sys_waitgroup_deinit(wg);
}
