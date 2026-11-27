#pragma once
#include <Foundation/Foundation.h>

#if defined(__clang__)
// The state of a for...in loop. GCC has it built in, with the same fields.
struct __objcFastEnumerationState {
  unsigned long state;         // Zero at the start, then the collection's own
  id *itemsPtr;                // The objects of this batch
  unsigned long *mutationsPtr; // A count of changes, which mustn't change
  unsigned long extra[5];      // For the collection's own use
};
#endif
