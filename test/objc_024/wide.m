#include <runtime/gcc/objc.h>

// This module has the method of the category, and only knows of that one. It
// declares the classes itself, without the method of the class.

int wide_value(void);

@interface Base : Object
@end

@interface Thing : Base
@end

@interface Thing (Wide)
+ (int)value:(long long)number;
@end

@implementation Thing (Wide)
+ (int)value:(long long)number {
  return (int)number + 1000;
}
@end

int wide_value(void) { return [Thing value:5]; }
