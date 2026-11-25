/**
 * @file test/TestObject.h
 * @brief A class which can be allocated, for tests without Foundation.
 */
#pragma once
#include <runtime/gcc/objc.h>

@interface TestObject : Object

// Allocate an instance, with its instance variables set to zero
+ (id)alloc;

// Free an instance
- (void)free;

@end
