#pragma once
#include <Foundation/Foundation.h>

@interface NXStream (Private)

/*
 * Returns the stream, or NULL if it's closed
 */
- (sys_iostream_t *)stream;

@end
