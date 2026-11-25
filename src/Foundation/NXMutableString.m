#include "NXString+Private.h"
#include "NXZone+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <string.h>

// The least that's allocated when a string needs more memory
#define MIN_CAPACITY 15

///////////////////////////////////////////////////////////////////////////////
// PRIVATE METHODS

static BOOL is_whitespace(char ch) {
  return ch == ' ' || (ch >= '\t' && ch <= '\r');
}

@interface NXMutableString (Private)
- (BOOL)append:(const char *)bytes length:(size_t)length;
@end

@implementation NXMutableString

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

+ (id)stringWithCapacity:(size_t)capacity {
  return [[[self alloc] initWithCapacity:capacity] autorelease];
}

- (id)initWithCapacity:(size_t)capacity {
  self = [self init];
  if (self != nil && capacity > 0) {
    if ([self allocateLength:capacity] == NULL) {
      [self release];
      return nil;
    }
    _data[0] = '\0';
    _length = 0;
  }
  return self;
}

- (void)dealloc {
  if (_data != NULL) {
    NXZoneFree([self zone], _data);
  }
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

- (size_t)length {
  return _length;
}

- (const char *)cStr {
  return _data == NULL ? "" : _data;
}

- (size_t)capacity {
  return _capacity;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

- (BOOL)appendString:(NXString *)other {
  return [self append:[other cStr] length:[other length]];
}

- (BOOL)appendCString:(const char *)cStr {
  return [self append:cStr length:cStr == NULL ? 0 : strlen(cStr)];
}

- (BOOL)appendFormat:(NXString *)format, ... {
  if (format == nil) {
    return YES;
  }
  va_list args;
  va_start(args, format);

  // Format it in the buffer, which is all that's needed if it fits
  BOOL appended = NO, fits = NO;
  size_t length;
  char *formatted = NXStringBufferAcquire();
  if (formatted == NULL) {
    length = NXStringFormat(NULL, 0, format, args);
  } else {
    length = NXStringFormat(formatted, NXSTRING_BUFFER_SIZE, format, args);
    fits = length < NXSTRING_BUFFER_SIZE;
    if (fits) {
      appended = [self append:formatted length:length];
    }
    NXStringBufferRelease();
  }

  // Otherwise, format it again, now that its length is known. That's not into this
  // string, as the arguments may include it.
  if (!fits) {
    char *data = length == SIZE_MAX ? NULL : sys_malloc(length + 1);
    if (data != NULL) {
      size_t actual = NXStringFormat(data, length + 1, format, args);
      appended = [self append:data length:actual < length ? actual : length];
      sys_free(data);
    }
  }
  va_end(args);
  return appended;
}

- (void)trimWhitespace {
  size_t start = 0;
  while (start < _length && is_whitespace(_data[start])) {
    start++;
  }
  size_t end = _length;
  while (end > start && is_whitespace(_data[end - 1])) {
    end--;
  }
  if (end - start != _length) {
    memmove(_data, _data + start, end - start);
    _length = end - start;
    _data[_length] = '\0';
  }
}

///////////////////////////////////////////////////////////////////////////////
// PRIVATE METHODS

- (char *)allocateLength:(size_t)length {
  objc_assert(_data == NULL);
  if (length == SIZE_MAX) {
    return NULL;
  }
  _data = NXZoneAlloc([self zone], length + 1);
  if (_data != NULL) {
    _data[length] = '\0';
    _length = _capacity = length;
  }
  return _data;
}

- (void)shortenLength:(size_t)length {
  _data[length] = '\0';
  _length = length;
}

@end

@implementation NXMutableString (Private)

- (BOOL)append:(const char *)bytes length:(size_t)length {
  if (length == 0) {
    return YES;
  }
  if (length > SIZE_MAX - 1 - _length) {
    return NO;
  }

  // At least double the capacity when there isn't room
  size_t required = _length + length;
  char *data = _data;
  if (required > _capacity) {
    size_t capacity = MIN_CAPACITY;
    if (_capacity > capacity / 2) {
      capacity = _capacity <= (SIZE_MAX - 1) / 2 ? _capacity * 2 : required;
    }
    if (capacity < required) {
      capacity = required;
    }
    data = NXZoneAlloc([self zone], capacity + 1);
    if (data == NULL) {
      return NO;
    }
    if (_length > 0) {
      memcpy(data, _data, _length);
    }
    _capacity = capacity;
  }

  // What's appended may be in this string, so that's freed last
  memmove(data + _length, bytes, length);
  data[required] = '\0';
  if (data != _data) {
    if (_data != NULL) {
      NXZoneFree([self zone], _data);
    }
    _data = data;
  }
  _length = required;
  return YES;
}

@end
