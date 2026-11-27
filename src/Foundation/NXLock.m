#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

@implementation NXLock

- (id)init {
  self = [super init];
  if (self != nil && (_mutex = sys_mutex_init()) == NULL) {
    [self release];
    return nil;
  }
  return self;
}

- (void)dealloc {
  if (_mutex != NULL) {
    sys_mutex_deinit(_mutex);
  }
  [super dealloc];
}

- (void)lock {
  if (!sys_mutex_lock(_mutex)) {
    sys_panicf("-[NXLock lock] failed");
  }
}

- (BOOL)tryLock {
  return sys_mutex_trylock(_mutex);
}

- (void)unlock {
  if (!sys_mutex_unlock(_mutex)) {
    sys_panicf("-[NXLock unlock] failed");
  }
}

@end
