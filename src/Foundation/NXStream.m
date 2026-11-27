#include "NXStream+Private.h"
#include "NXZone+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <string.h>

// The most that's read at a time, when reading a string
#define READ_SIZE 64

///////////////////////////////////////////////////////////////////////////////
// PRIVATE METHODS

@interface NXStream (Lifecycle)
- (id)initWithStream:(sys_iostream_t *)stream owned:(BOOL)owned;
@end

@interface NXStream (Peeked)
- (int *)peeked;
@end

@interface NXStream (Hash)
- (BOOL)hashPeeked:(sys_hash_t *)hash;
@end

// A byte of the standard input which has been peeked at, shared by all its streams
static int stdin_peeked = NXStreamEnd;

@implementation NXStream

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

+ (id)streamWithString:(NXString *)string {
  return [[[self alloc] initWithString:string] autorelease];
}

+ (id)streamWithCapacity:(size_t)capacity {
  return [[[self alloc] initWithCapacity:capacity] autorelease];
}

+ (id)streamWithBytes:(const void *)bytes length:(size_t)length {
  return [[[self alloc] initWithBytes:bytes length:length] autorelease];
}

+ (id)streamWithData:(NXData *)data {
  return [self streamWithBytes:[data bytes] length:[data length]];
}

+ (NXStream *)standardInput {
  return [[[self alloc] initWithStream:sys_stdin owned:NO] autorelease];
}

+ (NXStream *)standardOutput {
  return [[[self alloc] initWithStream:sys_stdout owned:NO] autorelease];
}

- (id)initWithString:(NXString *)string {
  // It's used for as long as the stream is, so it can't change
  NXString *copy;
  if (object_isKindOfClass(string, [NXMutableString class])) {
    copy = [[NXString alloc] initWithString:string];
  } else {
    copy = [string retain];
  }
  self = [self initWithStream:sys_string_read([copy cStr]) owned:YES];
  if (self == nil) {
    [copy release];
  } else {
    _string = copy;
  }
  return self;
}

- (id)initWithCapacity:(size_t)capacity {
  // There's a null terminator as well
  char *buffer = capacity == SIZE_MAX ? NULL
                                      : NXZoneAlloc([self zone], capacity + 1);
  NXZone *zone = [self zone];
  self = [self initWithStream:buffer == NULL
                                  ? NULL
                                  : sys_string_open(buffer, capacity + 1)
                        owned:YES];
  if (self != nil) {
    _buffer = buffer;
  } else if (buffer != NULL) {
    NXZoneFree(zone, buffer);
  }
  return self;
}

- (id)initWithBytes:(const void *)bytes length:(size_t)length {
  if (bytes == NULL && length > 0) {
    [self release];
    return nil;
  }
  self = [self initWithCapacity:length];
  if (self == nil) {
    return nil;
  }
  if (sys_iostream_write(_stream, bytes, length) != length ||
      sys_iostream_seek(_stream, 0, true) != 0) {
    [self release];
    return nil;
  }
  return self;
}

- (id)initWithStream:(sys_iostream_t *)stream {
  return [self initWithStream:stream owned:YES];
}

- (id)initWithStream:(sys_iostream_t *)stream owned:(BOOL)owned {
  self = [super init];
  if (self == nil || stream == NULL) {
    if (owned) {
      sys_iostream_close(stream);
    }
    [self release];
    return nil;
  }
  _stream = stream;
  _owned = owned;
  _peeked = NXStreamEnd;
  return self;
}

- (void)dealloc {
  [self close];
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

- (size_t)position {
  ptrdiff_t position = sys_iostream_seek(_stream, 0, false);
  return position < 0 ? NXNotFound : (size_t)position;
}

- (BOOL)seek:(ptrdiff_t)offset relative:(BOOL)relative {
  // Some streams without a position can go back a byte, which isn't wanted
  if (relative) {
    return [self position] != NXNotFound &&
           sys_iostream_seek(_stream, offset, false) >= 0;
  }
  return offset >= 0 && sys_iostream_seek(_stream, offset, true) >= 0;
}

- (BOOL)isEnded {
  return _stream == NULL ||
         (*[self peeked] == NXStreamEnd && sys_iostream_eof(_stream));
}

- (BOOL)isClosed {
  return _stream == NULL;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

- (int)peek {
  int *peeked = [self peeked];
  if (_stream == NULL) {
    return NXStreamEnd;
  }
  if (*peeked != NXStreamEnd) {
    return *peeked;
  }
  if (sys_iostream_seek(_stream, 0, false) >= 0) {
    return sys_iostream_peek(_stream);
  }

  // If the stream can't go back, keep the byte until it's read
  unsigned char byte;
  if (sys_iostream_read(_stream, (char *)&byte, 1) == 1) {
    *peeked = byte;
  }
  return *peeked;
}

- (size_t)readBytes:(void *)bytes length:(size_t)length {
  if (_stream == NULL || length == 0) {
    return 0;
  }
  int *peeked = [self peeked];
  if (*peeked != NXStreamEnd) {
    // There may be nothing else to read, in which case it might wait
    *(char *)bytes = (char)*peeked;
    *peeked = NXStreamEnd;
    return 1;
  }
  return sys_iostream_read(_stream, bytes, length);
}

- (NXString *)readStringWithLength:(size_t)length {
  char buffer[READ_SIZE + 1];
  NXMutableString *string = nil;
  BOOL has_position = [self position] != NXNotFound;
  while (length > 0) {
    size_t count = [self readBytes:buffer
                            length:length < READ_SIZE ? length : READ_SIZE];
    if (count == 0) {
      break;
    }
    buffer[count] = '\0';
    if (string == nil) {
      string = [NXMutableString string];
    }
    if (![string appendCString:buffer]) {
      return nil;
    }
    length -= count;

    // It stops at a zero byte
    if (strlen(buffer) < count) {
      break;
    }

    // Reading again might wait, unless it's known that it won't
    if (!has_position) {
      break;
    }
  }
  return string;
}

- (size_t)writeBytes:(const void *)bytes length:(size_t)length {
  return sys_iostream_write(_stream, bytes, length);
}

- (size_t)writeString:(NXString *)string {
  return [self writeBytes:[string cStr] length:[string length]];
}

- (NXString *)hashWithAlgorithm:(NXHashAlgorithm)algorithm {
  uint8_t bytes[NXHashMaxSize];
  size_t size = [self hashWithAlgorithm:algorithm bytes:bytes];
  if (size == 0) {
    return nil;
  }
  char hex[2 * NXHashMaxSize + 1];
  for (size_t i = 0; i < size; i++) {
    hex[2 * i] = "0123456789abcdef"[bytes[i] >> 4];
    hex[2 * i + 1] = "0123456789abcdef"[bytes[i] & 0x0F];
  }
  hex[2 * size] = '\0';
  return [NXString stringWithCString:hex];
}

- (size_t)hashWithAlgorithm:(NXHashAlgorithm)algorithm bytes:(void *)bytes {
  if (_stream == NULL) {
    return 0;
  }
  size_t size = 0;

#if SYS_HASH_CAPACITY == 1
  // There can only be one at a time, so wait until no other thread has it
  @synchronized([NXStream class]) {
#endif
    sys_hash_t *hash = sys_hash_init((sys_hash_algorithm_t)algorithm);
    if (hash != NULL) {
      if ([self hashPeeked:hash] && sys_hash_update(hash, _stream, 0)) {
        const uint8_t *digest = sys_hash_finalize(hash);
        if (digest != NULL) {
          size = sys_hash_size(hash);
          memcpy(bytes, digest, size);
        }
      }
      sys_hash_deinit(hash);
    }
#if SYS_HASH_CAPACITY == 1
  }
#endif
  return size;
}

- (void)close {
  // What's been peeked at in the standard input is kept, unless it's closed
  if (_owned || _stream != sys_stdin) {
    *[self peeked] = NXStreamEnd;
  }
  if (_owned) {
    sys_iostream_close(_stream);
  }
  _stream = NULL;
  _peeked = NXStreamEnd;
  [_string release];
  _string = nil;
  if (_buffer != NULL) {
    NXZoneFree([self zone], _buffer);
    _buffer = NULL;
  }
}

@end

@implementation NXStream (Peeked)

// Where a byte which has been peeked at is kept
- (int *)peeked {
  return _stream != NULL && _stream == sys_stdin ? &stdin_peeked : &_peeked;
}

@end

@implementation NXStream (Hash)

// Hash a byte which has been peeked at but not read, if there is one, and return YES if
// successful. Only what's in a stream can be hashed.
- (BOOL)hashPeeked:(sys_hash_t *)hash {
  int *peeked = [self peeked];
  if (*peeked == NXStreamEnd) {
    return YES;
  }
  char byte = (char)*peeked;
  char buffer[2];
  sys_iostream_t *stream = sys_string_open(buffer, sizeof(buffer));
  BOOL hashed = stream != NULL && sys_iostream_write(stream, &byte, 1) == 1 &&
                sys_iostream_seek(stream, 0, true) == 0 &&
                sys_hash_update(hash, stream, 1);
  sys_iostream_close(stream);
  if (hashed) {
    *peeked = NXStreamEnd;
  }
  return hashed;
}

@end

@implementation NXStream (Private)

- (sys_iostream_t *)stream {
  return _stream;
}

@end
