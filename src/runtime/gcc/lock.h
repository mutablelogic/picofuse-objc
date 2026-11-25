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
 * Read or write a word which other threads may be reading or writing. What was
 * written before a word was released has been written once it's been acquired.
 *
 * On an RP2040, the compiler calls a function which takes a spin lock for these,
 * which is too slow to do for each message. Reading and writing a word there is
 * always done all at once.
 */
#if defined(__ARM_ARCH_6M__)
#define OBJC_LOAD_RELAXED(ptr) (*(__typeof__(*(ptr)) volatile *)(ptr))
#define OBJC_LOAD_ACQUIRE(ptr)                                                 \
  ({                                                                           \
    __typeof__(*(ptr)) _value = OBJC_LOAD_RELAXED(ptr);                        \
    __atomic_thread_fence(__ATOMIC_ACQUIRE);                                   \
    _value;                                                                    \
  })
#define OBJC_STORE_RELEASE(ptr, value)                                         \
  do {                                                                         \
    __atomic_thread_fence(__ATOMIC_RELEASE);                                   \
    *(__typeof__(*(ptr)) volatile *)(ptr) = (value);                           \
  } while (0)
#else
#define OBJC_LOAD_RELAXED(ptr) __atomic_load_n(ptr, __ATOMIC_RELAXED)
#define OBJC_LOAD_ACQUIRE(ptr) __atomic_load_n(ptr, __ATOMIC_ACQUIRE)
#define OBJC_STORE_RELEASE(ptr, value)                                         \
  __atomic_store_n(ptr, value, __ATOMIC_RELEASE)
#endif

/*
 * Set a flag, with the runtime locked, or test for one, for which it needn't be.
 * What was written before a flag was set has been written once it's seen to be.
 */
static inline void __objc_flag_set(unsigned long *flags, unsigned long flag) {
  OBJC_STORE_RELEASE(flags, OBJC_LOAD_RELAXED(flags) | flag);
}

static inline bool __objc_flag_test(const unsigned long *flags,
                                    unsigned long flag) {
  return (OBJC_LOAD_ACQUIRE(flags) & flag) != 0;
}
