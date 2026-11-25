#include <picofuse/sys.h>
#include <test/TestObject.h>

@implementation TestObject

+ (id)alloc {
  id instance = (id)sys_calloc(1, class_getInstanceSize(self));
  if (instance != nil) {
    object_setClass(instance, self);
  }
  return instance;
}

- (void)free {
  sys_free(self);
}

@end
