#include "NXString+Private.h"
#include "NXZone+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <string.h>

///////////////////////////////////////////////////////////////////////////////
// GLOBALS

// Strings are formatted in this, if it's not in use
static char buffer[NXSTRING_BUFFER_SIZE];
static uint32_t buffer_used = 0;

///////////////////////////////////////////////////////////////////////////////
// PRIVATE METHODS

// Returns what replaces %@ in a format
static const char *format_object(id object) {
  if (object == nil) {
    return "<nil>";
  }
  if (!object_isKindOfClass(object, [NXString class])) {
    if (!object_respondsToSelector(object, @selector(description))) {
      return object_getClassName(object);
    }
    object = [(NXObject *)object description];
  }
  return object == nil ? "<nil>" : [(NXString *)object cStr];
}

static const char *format_handler(char specifier, va_list *args) {
  switch (specifier) {
  case '@':
    return format_object(va_arg(*args, id));
  case 't':
    return format_object(NXDurationDescription(va_arg(*args, NXDuration), 0));
  default:
    return NULL;
  }
}

size_t NXStringFormat(char *buffer, size_t size, NXString *format,
                      va_list args) {
  // This copies the arguments
  return sys_vsprintf_ex(buffer, size, [format cStr], args, format_handler);
}

// clang warns that this isn't lock-free on an RP2040, where pico-sdk implements it with
// a spin lock
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Watomic-alignment"
#endif

char *NXStringBufferAcquire(void) {
  return __atomic_exchange_n(&buffer_used, 1, __ATOMIC_ACQUIRE) ? NULL : buffer;
}

void NXStringBufferRelease(void) {
  __atomic_store_n(&buffer_used, 0, __ATOMIC_RELEASE);
}

#if defined(__clang__)
#pragma clang diagnostic pop
#endif

@implementation NXString

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

+ (id)allocWithZone:(NXZone *)zone {
  return self == [NXString class] ? [NXHeapString allocWithZone:zone]
                                  : [super allocWithZone:zone];
}

+ (id)string {
  return [[[self alloc] init] autorelease];
}

+ (id)stringWithString:(NXString *)other {
  return [[[self alloc] initWithString:other] autorelease];
}

+ (id)stringWithCString:(const char *)cStr {
  return [[[self alloc] initWithCString:cStr] autorelease];
}

+ (id)stringWithFormat:(NXString *)format, ... {
  va_list args;
  va_start(args, format);
  id string = [[[self alloc] initWithFormat:format arguments:args] autorelease];
  va_end(args);
  return string;
}

- (id)initWithBytes:(const void *)bytes length:(size_t)length {
  self = [self init];
  if (self != nil && length > 0) {
    char *data = [self allocateLength:length];
    if (data == NULL) {
      [self release];
      return nil;
    }
    memcpy(data, bytes, length);
  }
  return self;
}

- (id)initWithString:(NXString *)other {
  return [self initWithBytes:[other cStr] length:[other length]];
}

- (id)initWithCString:(const char *)cStr {
  return [self initWithBytes:cStr length:cStr == NULL ? 0 : strlen(cStr)];
}

- (id)initWithFormat:(NXString *)format, ... {
  va_list args;
  va_start(args, format);
  self = [self initWithFormat:format arguments:args];
  va_end(args);
  return self;
}

- (id)initWithFormat:(NXString *)format arguments:(va_list)args {
  self = [self init];
  if (self == nil || format == nil) {
    return self;
  }

  // Format it in the buffer, which is all that's needed if it fits
  size_t length;
  char *formatted = NXStringBufferAcquire();
  if (formatted == NULL) {
    length = NXStringFormat(NULL, 0, format, args);
  } else {
    length = NXStringFormat(formatted, NXSTRING_BUFFER_SIZE, format, args);
    BOOL fits = length < NXSTRING_BUFFER_SIZE;
    if (fits) {
      self = [self initWithBytes:formatted length:length];
    }
    NXStringBufferRelease();
    if (fits) {
      return self;
    }
  }

  // Otherwise, format it again, now that its length is known. A description may not be
  // the same as it was.
  if (length > 0) {
    char *data = [self allocateLength:length];
    if (data == NULL) {
      [self release];
      return nil;
    }
    size_t actual = NXStringFormat(data, length + 1, format, args);
    if (actual < length) {
      [self shortenLength:actual];
    }
  }
  return self;
}

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

- (size_t)length {
  sys_panicf("-[%s length] isn't implemented", object_getClassName(self));
}

- (const char *)cStr {
  sys_panicf("-[%s cStr] isn't implemented", object_getClassName(self));
}

- (NXString *)description {
  return self;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

- (BOOL)isEqual:(id)anObject {
  if (self == anObject) {
    return YES;
  }
  if (!object_isKindOfClass(anObject, [NXString class])) {
    return NO;
  }
  NXString *other = (NXString *)anObject;
  size_t length = [self length];
  return [other length] == length &&
         memcmp([self cStr], [other cStr], length) == 0;
}

@end

@implementation NXString (Private)

- (char *)allocateLength:(size_t)length {
  (void)length;
  sys_panicf("-[%s allocateLength:] isn't implemented",
             object_getClassName(self));
}

- (void)shortenLength:(size_t)length {
  (void)length;
  sys_panicf("-[%s shortenLength:] isn't implemented",
             object_getClassName(self));
}

@end

@implementation NXHeapString

- (void)dealloc {
  if (_data != NULL) {
    NXZoneFree([self zone], _data);
  }
  [super dealloc];
}

- (char *)allocateLength:(size_t)length {
  objc_assert(_data == NULL);
  if (length == SIZE_MAX) {
    return NULL;
  }
  _data = NXZoneAlloc([self zone], length + 1);
  if (_data != NULL) {
    _data[length] = '\0';
    _length = length;
  }
  return _data;
}

- (void)shortenLength:(size_t)length {
  _data[length] = '\0';
  _length = length;
}

- (size_t)length {
  return _length;
}

- (const char *)cStr {
  return _data == NULL ? "" : _data;
}

@end
