/**
 * @file test/TestString.h
 * @brief A class of constant strings, for tests without Foundation.
 */
#pragma once
#include <runtime/gcc/objc.h>

@interface TestString : Object {
  const char *_data;
  unsigned int _length;
}

- (const char *)cStr;
- (unsigned int)length;

@end
