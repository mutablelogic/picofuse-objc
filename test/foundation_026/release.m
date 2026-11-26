// NXDebug in a release build, where it does nothing
#ifndef NDEBUG
#define NDEBUG
#endif
#include <Foundation/Foundation.h>

int debug_in_release(int *evaluated) {
  NXDebug(@"%d", (*evaluated)++);
  return *evaluated;
}
