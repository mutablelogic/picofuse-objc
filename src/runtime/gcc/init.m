#include <runtime/gcc/objc.h>

/* Generate references to Object, NXConstantString and Protocol classes since
   they are needed by the runtime system to run correctly. */
void __objc_linking(void) {
  [Object name];
  [NXConstantString name];
  [Protocol name];
}
