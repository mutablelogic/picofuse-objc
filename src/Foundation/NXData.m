#include "NXObject+Private.h"
#include "NXZone+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <string.h>

// The least data has room for, once it has any
#define CAPACITY_MIN 16

@interface NXData (Private)
- (BOOL)reserve:(size_t)capacity;
@end

@implementation NXData

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

+ (id)data {
  return [[[self alloc] init] autorelease];
}

+ (id)dataWithCapacity:(size_t)capacity {
  return [[[self alloc] initWithCapacity:capacity] autorelease];
}

+ (id)dataWithBytes:(const void *)bytes length:(size_t)length {
  return [[[self alloc] initWithBytes:bytes length:length] autorelease];
}

+ (id)dataWithBase64String:(NXString *)string {
  return [[[self alloc] initWithBase64String:string] autorelease];
}

- (id)initWithCapacity:(size_t)capacity {
  self = [super init];
  if (self != nil && capacity > 0 && ![self reserve:capacity]) {
    [self release];
    return nil;
  }
  return self;
}

- (id)initWithBytes:(const void *)bytes length:(size_t)length {
  self = [self initWithCapacity:length];
  if (self != nil && ![self appendBytes:bytes length:length]) {
    [self release];
    return nil;
  }
  return self;
}

- (id)initWithBase64String:(NXString *)string {
  self = [super init];
  const char *cStr = [string cStr];
  size_t length = [string length];

  // A constant string can have a zero in it, which isn't base64
  ptrdiff_t size = -1;
  if (strnlen(cStr == NULL ? "" : cStr, length) == length) {
    size = length == 0 ? 0 : sys_string_parse_base64(cStr, length, NULL, 0);
  }
  if (self == nil || size < 0 || ![self reserve:(size_t)size]) {
    [self release];
    return nil;
  }
  if (size > 0) {
    _length = (size_t)sys_string_parse_base64(cStr, length, _bytes, _capacity);
  }
  return self;
}

- (void)dealloc {
  NXZoneFree([self zone], _bytes);
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

- (size_t)length {
  return _length;
}

- (size_t)capacity {
  return _capacity;
}

- (const void *)bytes {
  return _length == 0 ? NULL : _bytes;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

- (BOOL)appendBytes:(const void *)bytes length:(size_t)length {
  if (length == 0) {
    return YES;
  }
  if (bytes == NULL || length > SIZE_MAX - _length) {
    return NO;
  }

  // Twice the room, or as much as is needed, when there isn't enough
  if (_length + length > _capacity) {
    size_t capacity = _capacity < CAPACITY_MIN ? CAPACITY_MIN : _capacity;
    while (capacity < _length + length) {
      capacity = capacity > SIZE_MAX / 2 ? _length + length : capacity * 2;
    }

    // The bytes may be this data's own, which may move. Compare addresses
    // as integers, since relational comparisons between pointers to
    // different objects are undefined
    uintptr_t start = (uintptr_t)_bytes;
    uintptr_t at = (uintptr_t)bytes;
    if (_bytes != NULL && at >= start && at - start < _length) {
      size_t offset = (size_t)(at - start);
      if (![self reserve:capacity]) {
        return NO;
      }
      bytes = _bytes + offset;
    } else if (![self reserve:capacity]) {
      return NO;
    }
  }
  memmove(_bytes + _length, bytes, length);
  _length += length;
  return YES;
}

- (BOOL)appendData:(NXData *)data {
  return data == nil || [self appendBytes:data->_bytes length:data->_length];
}

- (NXString *)base64String {
  size_t length = sys_string_base64_encode(_bytes, _length, NULL, 0);
  if (length == 0) {
    return [NXString string];
  }
  char *buffer = length < SIZE_MAX ? sys_malloc(length + 1) : NULL;
  if (buffer == NULL) {
    return nil;
  }
  sys_string_base64_encode(_bytes, _length, buffer, length + 1);
  NXString *string = [NXString stringWithCString:buffer];
  sys_free(buffer);
  return string;
}

- (NXData *)hashWithAlgorithm:(NXHashAlgorithm)algorithm {
  uint8_t hash[NXHashMaxSize];
  NXStream *stream = [[NXStream alloc] initWithBytes:_bytes length:_length];
  size_t size = [stream hashWithAlgorithm:algorithm bytes:hash];
  [stream release];
  return size == 0 ? nil : [NXData dataWithBytes:hash length:size];
}

- (BOOL)isEqual:(id)anObject {
  if (anObject == self) {
    return YES;
  }
  if (anObject == nil || !object_isKindOfClass(anObject, [NXData class])) {
    return NO;
  }
  NXData *other = anObject;
  return other->_length == _length &&
         (_length == 0 || memcmp(other->_bytes, _bytes, _length) == 0);
}

- (uintptr_t)hash {
  uintptr_t hash = _length;
  for (size_t i = 0; i < _length; i++) {
    hash = NXHashCombine(hash, _bytes[i]);
  }
  return hash;
}

- (id)copy {
  NXData *copy = [[NXData allocInZone:[self zone]] initWithCapacity:_length];
  if (copy != nil && ![copy appendBytes:_bytes length:_length]) {
    [copy release];
    copy = nil;
  }
  return copy;
}

- (NXString *)description {
  NXMutableString *description =
      [NXMutableString stringWithCapacity:_length < (SIZE_MAX - 2) / 2
                                              ? _length * 2 + 2
                                              : 0];
  if (description == nil || ![description appendCString:"<"]) {
    return nil;
  }
  for (size_t i = 0; i < _length; i++) {
    char hex[3] = {"0123456789abcdef"[_bytes[i] >> 4], "0123456789abcdef"[_bytes[i] & 0x0F],
                   '\0'};
    if (![description appendCString:hex]) {
      return nil;
    }
  }
  return [description appendCString:">"] ? description : nil;
}

@end

@implementation NXData (Private)

// Makes room for a number of bytes, or returns NO if there isn't enough memory
- (BOOL)reserve:(size_t)capacity {
  if (capacity <= _capacity) {
    return YES;
  }
  if (capacity > PTRDIFF_MAX) {
    return NO; // more than any allocator can give
  }
  uint8_t *bytes = NXZoneRealloc([self zone], _bytes, _capacity, capacity);
  if (bytes == NULL) {
    return NO;
  }
  _bytes = bytes;
  _capacity = capacity;
  return YES;
}

@end
