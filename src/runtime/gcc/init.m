#include <runtime/gcc/objc.h>

/* Generate references to Object and Protocol classes since they are needed by the runtime system to run correctly. */
void __objc_linking(void) {
  [Object name];
  [Protocol name];
}
