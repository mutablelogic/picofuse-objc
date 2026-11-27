#include <picofuse/sys.h>
#include <runtime/gcc/runtime.h>

///////////////////////////////////////////////////////////////////////////////
// PUBLIC FUNCTIONS

// Called by the compiler in a for...in loop, when the collection's count of
// changes isn't what it was when the loop started. Carrying on could read
// objects which have moved or been released, so it stops here.
void objc_enumerationMutation(id object) {
  sys_panicf("Collection changed while it was being enumerated: %s",
             object_getClassName(object));
}
