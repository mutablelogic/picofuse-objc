#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

@implementation NXCondition

- (id)init {
  self = [super init];
  if (self != nil) {
    _mutex = sys_mutex_init();
    _cond = _mutex == NULL ? NULL : sys_cond_init();
    if (_cond == NULL) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  if (_cond != NULL) {
    sys_cond_deinit(_cond);
  }
  if (_mutex != NULL) {
    sys_mutex_deinit(_mutex);
  }
  [super dealloc];
}

- (void)lock {
  if (!sys_mutex_lock(_mutex)) {
    sys_panicf("-[NXCondition lock] failed");
  }
}

- (void)unlock {
  if (!sys_mutex_unlock(_mutex)) {
    sys_panicf("-[NXCondition unlock] failed");
  }
}

- (void)wait {
  if (!sys_cond_wait(_cond, _mutex)) {
    sys_panicf("-[NXCondition wait] failed");
  }
}

- (BOOL)waitForDuration:(NXDuration)duration {
  // picofuse waits for ever for 0 ms, so that's never asked for
  if (duration <= 0) {
    return NO;
  }
  NXDuration ms = (duration - 1) / NXMillisecond + 1;
  return sys_cond_timedwait(_cond, _mutex, ms > UINT32_MAX ? UINT32_MAX : (uint32_t)ms);
}

- (void)signal {
  if (!sys_cond_signal(_cond)) {
    sys_panicf("-[NXCondition signal] failed");
  }
}

- (void)broadcast {
  if (!sys_cond_broadcast(_cond)) {
    sys_panicf("-[NXCondition broadcast] failed");
  }
}

@end
