#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

// clang warns that atomics aren't lock-free on an RP2040, where pico-sdk implements
// them with a spin lock
#if defined(__clang__)
#pragma clang diagnostic ignored "-Watomic-alignment"
#endif

@implementation NXAtomic

+ (id)atomicWithUnsignedInt32:(uint32_t)value {
  return [[[self alloc] initWithUnsignedInt32:value] autorelease];
}

- (id)init {
  return [self initWithUnsignedInt32:0];
}

- (id)initWithUnsignedInt32:(uint32_t)value {
  self = [super init];
  if (self != nil) {
    sys_atomic_init(&_atomic, value);
  }
  return self;
}

- (uint32_t)unsignedInt32Value {
  return sys_atomic_get(&_atomic);
}

- (void)setUnsignedInt32Value:(uint32_t)value {
  sys_atomic_set(&_atomic, value);
}

- (BOOL)compareAndSwap:(uint32_t)expected with:(uint32_t)desired {
  return sys_atomic_compare_swap(&_atomic, &expected, desired);
}

- (uint32_t)increment {
  return sys_atomic_inc(&_atomic);
}

- (uint32_t)decrement {
  return sys_atomic_dec(&_atomic);
}

- (void)setBits:(uint32_t)mask {
  sys_atomic_set_bits(&_atomic, mask);
}

- (void)clearBits:(uint32_t)mask {
  sys_atomic_clear_bits(&_atomic, mask);
}

- (NXString *)description {
  return [NXString stringWithFormat:@"%u", (unsigned)[self unsignedInt32Value]];
}

@end
