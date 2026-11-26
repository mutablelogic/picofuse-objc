/**
 * @file NXStream.h
 * @brief Defines the NXStream class, for streams of bytes.
 */
#pragma once
#include "NXHashAlgorithm.h"
#include <picofuse/sys.h>
#include <stddef.h>

/**
 * @brief Returned by peek when there's nothing to read.
 * @ingroup Foundation
 */
#define NXStreamEnd SYS_IOSTREAM_EOF

/**
 * @brief A stream of bytes, which can be read or written.
 * @ingroup Foundation
 *
 * A stream reads from a string, reads and writes memory, is the standard input or output
 * of the program, or is any other stream of picofuse. Some streams have a position, which
 * can be changed.
 *
 * Reading and writing return how many bytes could be read or written at the time, which
 * may be fewer than were asked for, or none. Some streams wait until there's something to
 * read, such as the standard input on a Mac or Linux.
 *
 * There's a limit to how many streams can be open at once (SYS_IOSTREAM_CAPACITY), which
 * includes the standard input and output, so close them once they're no longer needed, if
 * they might not be deallocated soon. A stream shouldn't be used by two threads at the
 * same time.
 *
 * \headerfile NXStream.h Foundation/Foundation.h
 */
@interface NXStream : NXObject {
@private
  sys_iostream_t *_stream; ///< The stream, or NULL if it's closed
  BOOL _owned;             ///< Whether the stream is closed with this
  NXString *_string;       ///< What's read from, if it's a string
  char *_buffer;           ///< What's read and written, if it's memory
  int _peeked; ///< A byte which has been peeked at but not read, or NXStreamEnd
}

/**
 * @brief Returns a stream which reads from a string.
 * @return The stream, or nil if too many are open or there isn't enough memory.
 */
+ (id)streamWithString:(NXString *)string;

/**
 * @brief Returns a stream which reads and writes memory, and starts empty.
 * @param capacity The most bytes that can be written.
 * @return The stream, or nil if too many are open or there isn't enough memory.
 */
+ (id)streamWithCapacity:(size_t)capacity;

/**
 * @brief Returns a stream which reads and writes a copy of some bytes, from the start.
 * @param bytes The bytes, which can include zero, or NULL if the length is zero.
 * @param length The number of bytes, which is also the most that can be written.
 * @return The stream, or nil if too many are open or there isn't enough memory.
 */
+ (id)streamWithBytes:(const void *)bytes length:(size_t)length;

/**
 * @brief Returns a stream for the standard input, or nil if there isn't one.
 */
+ (NXStream *)standardInput;

/**
 * @brief Returns a stream for the standard output, or nil if there isn't one.
 */
+ (NXStream *)standardOutput;

/**
 * @brief Initializes a stream which reads from a string. If it's an NXMutableString, it
 * can be changed without affecting the stream.
 */
- (id)initWithString:(NXString *)string;

/**
 * @brief Initializes a stream which reads and writes memory, and starts empty.
 */
- (id)initWithCapacity:(size_t)capacity;

/**
 * @brief Initializes a stream which reads and writes a copy of some bytes, from the start.
 */
- (id)initWithBytes:(const void *)bytes length:(size_t)length;

/**
 * @brief Initializes a stream with one from picofuse, which is closed when this is, or if
 * this returns nil. It returns nil if that's NULL.
 */
- (id)initWithStream:(sys_iostream_t *)stream;

/**
 * @brief Returns the next byte, without reading it, or NXStreamEnd if there isn't one at
 * present.
 */
- (int)peek;

/**
 * @brief Reads bytes.
 * @param bytes Where to put what's read.
 * @param length The most bytes to read.
 * @return The number of bytes read, which is zero if there are none at present.
 */
- (size_t)readBytes:(void *)bytes length:(size_t)length;

/**
 * @brief Reads a string.
 * @param length The most bytes to read. A character may be split, if it's more than one.
 * @return The string, or nil if there's nothing to read at present or there isn't enough
 * memory. It stops at the first zero byte, although more may have been read. It may be
 * shorter than there is to read, if the stream doesn't have a position.
 */
- (NXString *)readStringWithLength:(size_t)length;

/**
 * @brief Writes bytes.
 * @return The number of bytes written, which may be fewer than the length, or zero if the
 * stream can't be written.
 */
- (size_t)writeBytes:(const void *)bytes length:(size_t)length;

/**
 * @brief Writes a string.
 * @return The number of bytes written, which may be fewer than its length.
 */
- (size_t)writeString:(NXString *)string;

/**
 * @brief Reads the rest of the stream, and returns a hash of it.
 * @return The hash, in lowercase hexadecimal, or nil if it isn't available or there isn't
 * enough memory.
 *
 * This reads until a read returns nothing. Unlike readStringWithLength:, that means
 * the standard input on Mac and Linux, or a pipe, is read until it's closed, which may
 * never happen. If the stream has a position, it's then at the end.
 */
- (NXString *)hashWithAlgorithm:(NXHashAlgorithm)algorithm;

/**
 * @brief Reads the rest of the stream, and returns a hash of it, as bytes.
 * @param algorithm The algorithm.
 * @param bytes Where to put the hash, which can be up to NXHashMaxSize bytes.
 * @return The size of the hash, or zero if it isn't available.
 */
- (size_t)hashWithAlgorithm:(NXHashAlgorithm)algorithm bytes:(void *)bytes;

/**
 * @brief Returns the position from the start, or NXNotFound if the stream doesn't have
 * one.
 */
- (size_t)position;

/**
 * @brief Changes the position.
 * @param offset The number of bytes from the start, or from the position if relative, in
 * which case it's backwards if negative.
 * @param relative YES if it's from the position, or NO if it's from the start.
 * @return YES if successful, or NO if the stream doesn't have a position, or it's before
 * the start or beyond the end, in which case it's not changed.
 */
- (BOOL)seek:(ptrdiff_t)offset relative:(BOOL)relative;

/**
 * @brief Returns YES if there'll never be anything else to read, as when a network
 * connection has been closed, or the stream has.
 *
 * It's NO at the end of a string or memory, as the position can be changed. To find out
 * if there's anything to read at present, use peek.
 */
- (BOOL)isEnded;

/**
 * @brief Closes the stream, which can't be used after that. Standard input and output
 * aren't themselves closed. It's closed when it's deallocated, if it hasn't been.
 */
- (void)close;

/**
 * @brief Returns YES if the stream has been closed.
 */
- (BOOL)isClosed;

@end
