#pragma once
#include <runtime/gcc/objc.h>

@protocol Shared
- (int)shared;
@end

@interface Other : Object <Shared>
+ (Protocol *)protocol;
@end
