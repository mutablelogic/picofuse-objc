#pragma once
#include <Foundation/Foundation.h>
#include <string.h>

/*
 * Checks of a method before it's called with a selector, by NXThread and the run loop of
 * the Application framework.
 */

// Returns the number of arguments a method has
static inline size_t NXMethodArguments(SEL selector) {
  size_t count = 0;
  for (const char *name = sel_getName(selector); *name != '\0'; name++) {
    if (*name == ':') {
      count++;
    }
  }
  return count;
}

// Returns YES if a method can be called as if it returned nothing. That's not so if
// it returns a struct, for example, as it's then passed where to put that.
static inline BOOL NXMethodReturnsScalar(const char *types) {
  types += strspn(types, "rnNoORVA"); // Qualifiers
  return *types != '\0' && strchr("v@#:*^cCsSiIlLqQBfd", *types) != NULL;
}

// Returns YES if the last argument of a method is an object. Each type is followed
// by the offset of the argument.
static inline BOOL NXMethodTakesObject(const char *types) {
  size_t length = strlen(types);
  while (length > 0 && strchr("0123456789+-", types[length - 1]) != NULL) {
    length--;
  }
  return length > 1 && strchr("@#", types[length - 1]) != NULL &&
         types[length - 2] != '^';
}
