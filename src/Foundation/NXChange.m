#include "NXChange+Private.h"
#include <picofuse/sys.h>
#if !defined(SYSTEM_NAME_PICO)
#include <pthread.h>
#endif

// clang warns that atomics aren't lock-free on an RP2040
#if defined(__clang__)
#pragma clang diagnostic ignored "-Watomic-alignment"
#endif

uintptr_t NXThreadIdentity(void) {
#if defined(SYSTEM_NAME_PICO)
  return (uintptr_t)sys_thread_core() + 1; // a thread for each core
#else
  return (uintptr_t)pthread_self();
#endif
}

void NXChangeBegin(uintptr_t *changing, const char *method) {
  uintptr_t self = NXThreadIdentity();
  uintptr_t owner = 0;
  if (!__atomic_compare_exchange_n(changing, &owner, self, false, __ATOMIC_ACQUIRE,
                                   __ATOMIC_RELAXED)) {
    if (owner == self) {
      sys_panicf("%s changed while it was being changed", method);
    }
    sys_panicf("%s changed by two threads at once", method);
  }
}

void NXChangeEnd(uintptr_t *changing) {
  __atomic_store_n(changing, 0, __ATOMIC_RELEASE);
}

void NXReadCheckFailed(uintptr_t owner, const char *method) {
  if (owner != NXThreadIdentity()) {
    sys_panicf("%s used while another thread changes it", method);
  }
}
