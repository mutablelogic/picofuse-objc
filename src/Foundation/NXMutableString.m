#include "NXChange+Private.h"
#include "NXObject+Private.h"
#include "NXString+Private.h"
#include "NXZone+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <string.h>

// The least that's allocated when a string needs more memory
#define MIN_CAPACITY 15

@interface NXMutableString (Private)
- (BOOL)append:(const char *)bytes length:(size_t)length method:(const char *)method;
- (BOOL)add:(const char *)bytes length:(size_t)length;
@end

@implementation NXMutableString

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

+ (id)stringWithCapacity:(size_t)capacity {
  return [[[self alloc] initWithCapacity:capacity] autorelease];
}

- (id)initWithCapacity:(size_t)capacity {
  self = [super init];
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

- (id)copy {
  return [[NXString allocInZone:[self zone]] initWithString:self];
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
  NXReadCheck(&_changing, __func__);
  return _length;
}

- (const char *)cStr {
  NXReadCheck(&_changing, __func__);
  return _data == NULL ? "" : _data;
}

- (size_t)capacity {
  return _capacity;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

- (BOOL)appendString:(NXString *)other {
  return [self append:[other cStr] length:[other length] method:__func__];
}

- (BOOL)appendCString:(const char *)cStr {
  return [self append:cStr length:cStr == NULL ? 0 : strlen(cStr) method:__func__];
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
      appended = [self append:formatted length:length method:__func__];
    }
    NXStringBufferRelease();
  }

  // Otherwise, format it again, now that its length is known. That's not into this
  // string, as the arguments may include it.
  if (!fits) {
    char *data = length == SIZE_MAX ? NULL : sys_malloc(length + 1);
    if (data != NULL) {
      size_t actual = NXStringFormat(data, length + 1, format, args);
      appended = [self append:data length:actual < length ? actual : length method:__func__];
      sys_free(data);
    }
  }
  va_end(args);
  return appended;
}

- (void)trimWhitespace {
  NXChangeBegin(&_changing, __func__);
  sys_string_trimspace(_data);
  _length = sys_string_bytes(_data);
  NXChangeEnd(&_changing);
}

- (BOOL)trimPrefix:(NXString *)prefix {
  NXChangeBegin(&_changing, __func__);
  size_t length = _length;
  sys_string_trimprefix(_data, [prefix cStr]);
  _length = sys_string_bytes(_data);
  NXChangeEnd(&_changing);
  return _length != length;
}

- (BOOL)trimSuffix:(NXString *)suffix {
  NXChangeBegin(&_changing, __func__);
  size_t length = _length;
  sys_string_trimsuffix(_data, [suffix cStr]);
  _length = sys_string_bytes(_data);
  NXChangeEnd(&_changing);
  return _length != length;
}

- (void)toUppercase {
  NXChangeBegin(&_changing, __func__);
  sys_string_to_upper(_data);
  NXChangeEnd(&_changing);
}

- (void)toLowercase {
  NXChangeBegin(&_changing, __func__);
  sys_string_to_lower(_data);
  NXChangeEnd(&_changing);
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

// Appends bytes, which can be the string's own, as a change by a method
- (BOOL)append:(const char *)bytes length:(size_t)length method:(const char *)method {
  NXChangeBegin(&_changing, method);
  BOOL appended = [self add:bytes length:length];
  NXChangeEnd(&_changing);
  return appended;
}

- (BOOL)add:(const char *)bytes length:(size_t)length {
  if (length > 0) {
    length = strnlen(bytes, length);
  }
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
