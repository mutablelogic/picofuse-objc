#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

@implementation NXWaitGroup

- (id)init {
  self = [super init];
  if (self != nil && (_waitgroup = sys_waitgroup_init()) == NULL) {
    [self release];
    return nil;
  }
  return self;
}

- (void)dealloc {
  if (_waitgroup != NULL) {
    sys_waitgroup_deinit(_waitgroup);
  }
  [super dealloc];
}

- (void)add:(int)count {
  if (!sys_waitgroup_add(_waitgroup, count)) {
    sys_panicf("-[NXWaitGroup add:] can't add %d", count);
  }
}

- (void)done {
  if (!sys_waitgroup_done(_waitgroup)) {
    sys_panicf("-[NXWaitGroup done] the count is already zero");
  }
}

- (void)wait {
  sys_waitgroup_wait(_waitgroup);
}

@end
