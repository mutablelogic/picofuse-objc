#pragma once
#include <stdbool.h>
#include <stdint.h>

/*
 * Returns a value which identifies the current thread, and is never zero. On a
 * Pico, there's one thread per core.
 */
uintptr_t __objc_thread_self(void);

/*
 * Lock and unlock the runtime, in order to change its tables. A thread can lock it
 * again which has already locked it. Unlike picofuse's mutexes, this can be used
 * before sys_init() is called, as messages can be sent before then.
 */
void __objc_lock(void);
void __objc_unlock(void);

/*
 * Pause, when waiting for another thread
 */
void __objc_lock_wait(void);

/*
 * Set a flag, or test for one which may have been set by another thread. What was
 * written before a flag was set has been written once it's seen to be. A flag can
 * only be set with the runtime locked, but can be tested without.
 */
static inline void __objc_flag_set(unsigned long *flags, unsigned long flag) {
  __atomic_thread_fence(__ATOMIC_RELEASE);
  *(volatile unsigned long *)flags |= flag;
}

static inline bool __objc_flag_test(const unsigned long *flags,
                                    unsigned long flag) {
  bool set = (*(const volatile unsigned long *)flags & flag) != 0;
  __atomic_thread_fence(__ATOMIC_ACQUIRE);
  return set;
}
