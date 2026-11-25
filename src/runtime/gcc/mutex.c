#include "lock.h"
#include <runtime/gcc/objc.h>
#include <picofuse/sys.h>

///////////////////////////////////////////////////////////////////////////////
// TYPES

/*
 * The objects which are locked at present. Every object can be locked, but it
 * only needs an entry here while it is. That's done with a single mutex and
 * condition variable from picofuse, which has a limited number of both, and
 * whose mutexes can't be locked again by the thread which holds them.
 */
struct objc_sync_lock {
  id object;       // The locked object, or nil if the entry is free
  uintptr_t owner; // The thread which holds the lock
  size_t depth;    // How many times that thread has locked it
};

///////////////////////////////////////////////////////////////////////////////
// GLOBALS

static struct objc_sync_lock sync_locks[OBJC_SYNC_CAPACITY];
static sys_mutex_t *sync_mutex = NULL; // Guards sync_locks and sync_waiting
static sys_cond_t *sync_cond = NULL;   // Broadcast when a lock is released
static size_t sync_waiting = 0;        // Number of threads waiting for a lock

///////////////////////////////////////////////////////////////////////////////
// PRIVATE METHODS

// clang warns that these aren't lock-free on an RP2040, where pico-sdk implements
// them with a spin lock. Only the first load is used more than once.
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Watomic-alignment"
#endif

/*
 * Create the mutex and condition variable the first time they're needed, as
 * they can't be until sys_init() has been called.
 */
static void __objc_sync_init(void) {
  static int state = 0; // 0 = not initialized, 1 = in progress, 2 = done
  if (__atomic_load_n(&state, __ATOMIC_ACQUIRE) == 2) {
    return;
  }

  int expected = 0;
  if (__atomic_compare_exchange_n(&state, &expected, 1, false, __ATOMIC_ACQUIRE,
                                  __ATOMIC_ACQUIRE)) {
    sync_mutex = sys_mutex_init();
    sync_cond = sys_cond_init();
    if (sync_mutex == NULL || sync_cond == NULL) {
      sys_panicf("objc_sync_enter: no mutex or condition variable available");
    }
    __atomic_store_n(&state, 2, __ATOMIC_RELEASE);
  } else {
    // Another thread is doing it
    while (__atomic_load_n(&state, __ATOMIC_ACQUIRE) != 2) {
      sys_sleep_ms(1);
    }
  }
}

#if defined(__clang__)
#pragma clang diagnostic pop
#endif

/*
 * Returns the entry for an object, or for nil, a free entry. Returns NULL if
 * there isn't one.
 */
static struct objc_sync_lock *__objc_sync_find(id object) {
  for (size_t i = 0; i < OBJC_SYNC_CAPACITY; i++) {
    if (sync_locks[i].object == object) {
      return &sync_locks[i];
    }
  }
  return NULL;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

/**
 * @brief Acquire a lock on the specified object for thread synchronization.
 */
int objc_sync_enter(id obj) {
  if (obj == nil) {
    return 0;
  }

  __objc_sync_init();
  uintptr_t self = __objc_thread_self();
  if (!sys_mutex_lock(sync_mutex)) {
    sys_panicf("objc_sync_enter: cannot lock mutex");
  }

  // Wait until no other thread has the lock
  struct objc_sync_lock *lock;
  while ((lock = __objc_sync_find(obj)) != NULL && lock->owner != self) {
    sync_waiting++;
    sys_cond_wait(sync_cond, sync_mutex);
    sync_waiting--;
  }

  if (lock == NULL) {
    lock = __objc_sync_find(nil);
    if (lock == NULL) {
      sys_panicf("objc_sync_enter: more than %d objects are locked",
                 OBJC_SYNC_CAPACITY);
    }
    lock->object = obj;
    lock->owner = self;
    lock->depth = 0;
  }
  lock->depth++;

  sys_mutex_unlock(sync_mutex);
  return 0;
}

/**
 * @brief Release a lock on the specified object.
 */
int objc_sync_exit(id obj) {
  if (obj == nil) {
    return 0;
  }

  __objc_sync_init();
  uintptr_t self = __objc_thread_self();
  if (!sys_mutex_lock(sync_mutex)) {
    sys_panicf("objc_sync_exit: cannot lock mutex");
  }

  int result = 0;
  struct objc_sync_lock *lock = __objc_sync_find(obj);
  if (lock == NULL || lock->owner != self) {
    result = 1; // The current thread doesn't hold the lock
  } else if (--lock->depth == 0) {
    lock->object = nil;
    if (sync_waiting > 0) {
      sys_cond_broadcast(sync_cond);
    }
  }

  sys_mutex_unlock(sync_mutex);
  return result;
}

/**
 * @brief Called to unwind the stack through Objective-C code.
 *
 * GCC refers to this wherever @synchronized is used, in order to release the
 * lock if an exception is thrown. There are no exceptions in this runtime, so
 * it should never be called.
 */
int __gnu_objc_personality_v0(void);
int __gnu_objc_personality_v0(void) {
  sys_panicf("Objective-C exceptions are not supported");
}
