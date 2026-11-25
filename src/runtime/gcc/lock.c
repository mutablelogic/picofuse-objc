#include "lock.h"
#include <picofuse/sys.h>

#ifndef SYSTEM_NAME_PICO
#include <pthread.h>
#endif

// How many times to try for the lock before pausing
#define SPIN_COUNT 100

// clang warns that these aren't lock-free on an RP2040, where pico-sdk implements
// them with a spin lock
#if defined(__clang__)
#pragma clang diagnostic ignored "-Watomic-alignment"
#endif

///////////////////////////////////////////////////////////////////////////////
// GLOBALS

static uintptr_t lock_owner = 0; // The thread which has the lock, or zero
static unsigned lock_depth = 0;  // How many times that thread has locked it

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

uintptr_t __objc_thread_self(void) {
#ifdef SYSTEM_NAME_PICO
  return (uintptr_t)sys_thread_core() + 1;
#else
  return (uintptr_t)pthread_self();
#endif
}

void __objc_lock_wait(void) { sys_sleep_ms(1); }

void __objc_lock(void) {
  uintptr_t self = __objc_thread_self();
  if (__atomic_load_n(&lock_owner, __ATOMIC_RELAXED) != self) {
    uintptr_t expected = 0;
    unsigned spin = 0;
    while (!__atomic_compare_exchange_n(&lock_owner, &expected, self, false,
                                        __ATOMIC_ACQUIRE, __ATOMIC_RELAXED)) {
      expected = 0;
      if (++spin >= SPIN_COUNT) {
        __objc_lock_wait();
      }
    }
  }
  lock_depth++;
}

void __objc_unlock(void) {
  if (--lock_depth == 0) {
    __atomic_store_n(&lock_owner, 0, __ATOMIC_RELEASE);
  }
}
