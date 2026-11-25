#include <test/test.h>

// Two threads send the first messages to a class at the same time. Nothing is sent
// a message before that.

static sys_waitgroup_t *wg = NULL;

// Wait for both threads to get to the same step
static sys_atomic_t arrived;
static void rendezvous(uint32_t step) {
  sys_atomic_inc(&arrived);
  while (sys_atomic_get(&arrived) < 2 * (step + 1)) {
  }
}

#define CLASS(n)                                                               \
  @interface C##n : Object                                                     \
  +(int)a;                                                                     \
  +(int)b;                                                                     \
  +(int)c;                                                                     \
  @end                                                                         \
  @implementation C##n                                                         \
  +(int)a {                                                                    \
    return 1;                                                                  \
  }                                                                            \
  +(int)b {                                                                    \
    return 2;                                                                  \
  }                                                                            \
  +(int)c {                                                                    \
    return n;                                                                  \
  }                                                                            \
  @end                                                                         \
  @interface D##n : C##n                                                       \
  @end                                                                         \
  @implementation D##n                                                         \
  @end

#define CHECK(n)                                                               \
  rendezvous(step++);                                                          \
  test_assert([D##n c] == n);

#define TEN(X, n)                                                              \
  X(n##0) X(n##1) X(n##2) X(n##3) X(n##4)                                      \
  X(n##5) X(n##6) X(n##7) X(n##8) X(n##9)
#define FIFTY(X) TEN(X, 1) TEN(X, 2) TEN(X, 3) TEN(X, 4) TEN(X, 5)

FIFTY(CLASS)

// The other thread waits until this has been initialized, which takes a while
static sys_atomic_t slow_calls;
static volatile int slow_value = 0;

@interface Slow : Object
+ (int)value;
@end

@implementation Slow
+ (void)initialize {
  sys_atomic_inc(&slow_calls);
  sys_sleep_ms(100);
  slow_value = [self value] + 42;
}
+ (int)value {
  return slow_value;
}
@end

// This waits for the other thread to send a message to another class, which it does
// at the same time
static sys_atomic_t other_done;

@interface Other : Object
+ (void)done;
@end

@implementation Other
+ (void)done {
  sys_atomic_set(&other_done, 1);
}
@end

@interface Waiter : Object
+ (int)value;
@end

@implementation Waiter
+ (void)initialize {
  for (int i = 0; i < 2000 && sys_atomic_get(&other_done) == 0; i++) {
    sys_sleep_ms(1);
  }
}
+ (int)value {
  return sys_atomic_get(&other_done);
}
@end

static void work(BOOL waiter) {
  uint32_t step = 0;
  FIFTY(CHECK)

  rendezvous(step++);
  test_assert([Slow value] == 42);

  rendezvous(step++);
  if (waiter) {
    test_assert([Waiter value] == 1);
  } else {
    [Other done];
  }
}

static void thread(void *arg) {
  (void)arg;
  work(NO);
  sys_waitgroup_done(wg);
}

test_main(0) {
  if (sys_thread_numcores() < 2) {
    return;
  }
  wg = sys_waitgroup_init();
  test_assert(wg != NULL);
  test_assert(sys_waitgroup_add(wg, 1));
  test_assert(sys_thread_create(thread, NULL));
  work(YES);
  sys_waitgroup_wait(wg);
  test_assert(sys_atomic_get(&slow_calls) == 1);
}
