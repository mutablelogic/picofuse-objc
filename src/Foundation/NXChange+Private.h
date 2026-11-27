#pragma once
#include <Foundation/Foundation.h>
#include <stdint.h>

/*
 * Catching an object which can change being used by threads without a lock. The
 * object keeps the thread which is changing it, or zero, in a uintptr_t:
 *
 * - NXChangeBegin() and NXChangeEnd() go around each change. A change by another thread
 *   at the same time panics, and so does a change by the same thread in the middle of
 *   one, as from an isEqual: which the change called.
 * - NXReadCheck() starts each read, and panics if another thread is changing it. The
 *   same thread can read it during a change.
 *
 * It's best effort, like Go's check of maps: threads are caught when their uses
 * overlap at the check, not always. A read costs a relaxed load and a comparison.
 * method is the name of the method, for the panic.
 */

// The current thread, which isn't zero
uintptr_t NXThreadIdentity(void);

void NXChangeBegin(uintptr_t *changing, const char *method);
void NXChangeEnd(uintptr_t *changing);
void NXReadCheckFailed(uintptr_t owner, const char *method);

// clang warns that atomics aren't lock-free on an RP2040
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Watomic-alignment"
#endif

static inline void NXReadCheck(const uintptr_t *changing, const char *method) {
  uintptr_t owner = __atomic_load_n(changing, __ATOMIC_RELAXED);
  if (owner != 0) {
    NXReadCheckFailed(owner, method);
  }
}

#if defined(__clang__)
#pragma clang diagnostic pop
#endif
