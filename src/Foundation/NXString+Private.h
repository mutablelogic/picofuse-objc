#pragma once
#include <Foundation/Foundation.h>
#include <stdarg.h>

@interface NXString (Private)

/*
 * Make room for a string of a length, when it's being initialized, and return where
 * to put it. The null terminator is already there. Returns NULL if there isn't enough
 * memory.
 */
- (char *)allocateLength:(size_t)length;

/*
 * Make the string shorter than was allocated
 */
- (void)shortenLength:(size_t)length;

@end

/*
 * A string on the heap, which can't be changed. It's what [NXString alloc] returns.
 */
@interface NXHeapString : NXString {
@private
  char *_data; // The contents, or NULL if it's empty
  size_t _length;
}
@end

/*
 * Format a string in a buffer, and return its length, without the null terminator,
 * which may be more than fits. The buffer can be NULL if its size is zero. The arguments
 * can be used again.
 */
size_t NXStringFormat(char *buffer, size_t size, NXString *format, va_list args);

/*
 * The size of the buffer for strings to be formatted in, which is static. Those which
 * fit are only formatted once.
 */
#ifndef NXSTRING_BUFFER_SIZE
#define NXSTRING_BUFFER_SIZE 128
#endif

/*
 * Returns the buffer, or NULL if it's in use, which may be by the calling thread, as the
 * description of an object may itself be formatted. It has to be released if it isn't
 * NULL.
 */
char *NXStringBufferAcquire(void);
void NXStringBufferRelease(void);
