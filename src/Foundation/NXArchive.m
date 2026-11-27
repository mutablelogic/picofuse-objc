#include "NXNumber+Private.h"
#include "NXObject+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <runtime/gcc/runtime.h>
#include <string.h>

#define DEPTH_DEFAULT 32

// Where the encoder is, at each level: in an object or an array, and how many values
// have been written there
typedef struct {
  char kind; // '{' or '[', or 0 at the top
  size_t count;
} level_t;

///////////////////////////////////////////////////////////////////////////////
// PRIVATE FUNCTIONS

// Returns YES if a class is another, or a subclass of it
static BOOL is_subclass(Class cls, Class of) {
  for (; cls != Nil; cls = class_getSuperclass(cls)) {
    if (cls == of) {
      return YES;
    }
  }
  return NO;
}

static BOOL is_archiving(Class cls) {
  return class_conformsTo(cls, (objc_protocol_t *)@protocol(NXArchiving));
}

// Returns YES if a token is a number as JSON writes them: an optional minus, digits
// without a leading zero, then an optional fraction and exponent
static BOOL is_json_number(const char *s, size_t length, BOOL *integer) {
  size_t i = 0;
  *integer = YES;
  if (i < length && s[i] == '-') {
    i++;
  }
  if (i >= length || s[i] < '0' || s[i] > '9') {
    return NO;
  }
  if (s[i] == '0' && i + 1 < length && s[i + 1] >= '0' && s[i + 1] <= '9') {
    return NO;
  }
  while (i < length && s[i] >= '0' && s[i] <= '9') {
    i++;
  }
  if (i < length && s[i] == '.') {
    *integer = NO;
    i++;
    if (i >= length || s[i] < '0' || s[i] > '9') {
      return NO;
    }
    while (i < length && s[i] >= '0' && s[i] <= '9') {
      i++;
    }
  }
  if (i < length && (s[i] == 'e' || s[i] == 'E')) {
    *integer = NO;
    i++;
    if (i < length && (s[i] == '+' || s[i] == '-')) {
      i++;
    }
    if (i >= length || s[i] < '0' || s[i] > '9') {
      return NO;
    }
    while (i < length && s[i] >= '0' && s[i] <= '9') {
      i++;
    }
  }
  return i == length;
}

@interface NXArchive (Private)
- (id)initWithStream:(NXStream *)stream encoding:(BOOL)encoding indent:(unsigned)indent;
- (void)fail:(NXString *)format, ...;
- (BOOL)write:(const char *)bytes length:(size_t)length;
- (BOOL)writeCString:(const char *)cStr;
- (BOOL)writeQuoted:(NXString *)string;
- (BOOL)writeIndent;
- (BOOL)beginValueForKey:(NXString *)key;
- (BOOL)open:(char)kind;
- (BOOL)close;
- (BOOL)encodeNumber:(NXNumber *)number forKey:(NXString *)key;
- (BOOL)read;
- (BOOL)nextToken:(NXScanner *)scanner;
- (id)parseValue:(NXScanner *)scanner depth:(unsigned)depth;
- (id)valueForKey:(NXString *)key;
- (id)convert:(id)value toClass:(Class)cls key:(NXString *)key;
- (NXNumber *)numberForKey:(NXString *)key;
- (BOOL)integerForKey:(NXString *)key
             negative:(BOOL *)negative
            magnitude:(uint64_t *)magnitude;
@end

@implementation NXArchive

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

+ (id)JSONEncoderWithStream:(NXStream *)stream indent:(unsigned)indent {
  return [[[self alloc] initWithStream:stream encoding:YES indent:indent] autorelease];
}

+ (id)JSONDecoderWithStream:(NXStream *)stream {
  return [[[self alloc] initWithStream:stream encoding:NO indent:0] autorelease];
}

+ (BOOL)encodeObject:(id)object toStream:(NXStream *)stream format:(NXArchiveFormat)format {
  (void)format;
  NXArchive *archive = [self JSONEncoderWithStream:stream indent:0];
  return archive != nil && [archive encodeObject:object forKey:nil];
}

+ (id)decodeObjectOfClass:(Class)cls
               fromStream:(NXStream *)stream
                   format:(NXArchiveFormat)format {
  (void)format;
  NXArchive *archive = [self JSONDecoderWithStream:stream];
  id object = [archive decodeObjectOfClass:cls forKey:nil];
  return [archive failed] ? nil : object;
}

- (void)dealloc {
  [_stream release];
  [_failure release];
  [_root release];
  sys_free(_levels);
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

- (NXArchiveFormat)format {
  return NXArchiveFormatJSON;
}

- (BOOL)isEncoding {
  return _encoding;
}

- (BOOL)failed {
  if (!_encoding) {
    [self read];
  }
  return _failure != nil;
}

- (NXString *)failure {
  [self failed];
  return _failure;
}

- (void)setMaximumDepth:(unsigned)depth {
  if (_levels == NULL && !_read) {
    _maxDepth = depth;
  }
}

- (void)setMaximumLength:(size_t)length {
  if (!_read) {
    _maxLength = length;
  }
}

///////////////////////////////////////////////////////////////////////////////
// ENCODING

- (BOOL)encodeBool:(BOOL)value forKey:(NXString *)key {
  return [self beginValueForKey:key] && [self writeCString:value ? "true" : "false"];
}

- (BOOL)encodeInt32:(int32_t)value forKey:(NXString *)key {
  return [self encodeInt64:value forKey:key];
}

- (BOOL)encodeInt64:(int64_t)value forKey:(NXString *)key {
  char buffer[32];
  sys_sprintf(buffer, sizeof(buffer), "%ld", value);
  return [self beginValueForKey:key] && [self writeCString:buffer];
}

- (BOOL)encodeUnsignedInt32:(uint32_t)value forKey:(NXString *)key {
  return [self encodeUnsignedInt64:value forKey:key];
}

- (BOOL)encodeUnsignedInt64:(uint64_t)value forKey:(NXString *)key {
  char buffer[32];
  sys_sprintf(buffer, sizeof(buffer), "%lu", value);
  return [self beginValueForKey:key] && [self writeCString:buffer];
}

- (BOOL)encodeFloat32:(float)value forKey:(NXString *)key {
  if (value != value || value - value != 0) {
    [self fail:@"%@ isn't a finite number, which JSON can't have", key];
    return NO;
  }
  char buffer[32];
  sys_sprintf(buffer, sizeof(buffer), "%.9g", (double)value);
  return [self beginValueForKey:key] && [self writeCString:buffer];
}

- (BOOL)encodeFloat64:(double)value forKey:(NXString *)key {
  if (value != value || value - value != 0) {
    [self fail:@"%@ isn't a finite number, which JSON can't have", key];
    return NO;
  }

  // The fewest digits which read back as the same value
  static const char *formats[] = {"%.15g", "%.16g", "%.17g"};
  char buffer[32];
  for (size_t i = 0; i < sizeof(formats) / sizeof(formats[0]); i++) {
    sys_sprintf(buffer, sizeof(buffer), formats[i], value);
    double read;
    if (sys_string_parse_float64(buffer, 0, &read) && read == value) {
      break;
    }
  }
  return [self beginValueForKey:key] && [self writeCString:buffer];
}

- (BOOL)encodeObject:(id)object forKey:(NXString *)key {
  if (_failure != nil || !_encoding) {
    return NO;
  }
  if (object == nil || object == [NXNull nullValue]) {
    return [self beginValueForKey:key] && [self writeCString:"null"];
  }
  if (object_isKindOfClass(object, [NXString class])) {
    return [self beginValueForKey:key] && [self writeQuoted:object];
  }
  if (object_isKindOfClass(object, [NXNumber class])) {
    return [self encodeNumber:object forKey:key];
  }
  if (object_isKindOfClass(object, [NXData class])) {
    NXString *base64 = [object base64String];
    if (base64 == nil) {
      [self fail:@"not enough memory for %@", key];
      return NO;
    }
    return [self beginValueForKey:key] && [self writeQuoted:base64];
  }
  if (object_isKindOfClass(object, [NXDate class])) {
    return [self beginValueForKey:key] &&
           [self writeQuoted:[object stringWithFormat:NXDateFormatISO8601]];
  }
  if (object_isKindOfClass(object, [NXArray class])) {
    if (![self beginValueForKey:key] || ![self open:'[']) {
      return NO;
    }
    for (id element in (NXArray *)object) {
      if (![self encodeObject:element forKey:nil]) {
        return NO;
      }
    }
    return [self close];
  }
  if (object_isKindOfClass(object, [NXMap class])) {
    // In order, so the same map is always written the same way
    NXArray *keys = [object allKeys];
    for (id k in keys) {
      if (!object_isKindOfClass(k, [NXString class])) {
        [self fail:@"a map's keys have to be strings in JSON, not %s",
                   object_getClassName(k)];
        return NO;
      }
    }
    if (keys == nil || ![keys sortUsingSelector:@selector(compare:)]) {
      [self fail:@"not enough memory for %@", key];
      return NO;
    }
    if (![self beginValueForKey:key] || ![self open:'{']) {
      return NO;
    }
    for (NXString *k in keys) {
      if (![self encodeObject:[object objectForKey:k] forKey:k]) {
        return NO;
      }
    }
    return [self close];
  }
  if (is_archiving(object_getClass(object))) {
    Class named = _class;
    _class = Nil;
    if (![self beginValueForKey:key] || ![self open:'{']) {
      return NO;
    }
    if (named != Nil && ![self encodeObject:[NXString stringWithCString:class_getName(named)]
                                     forKey:@"@class"]) {
      return NO;
    }
    if (![object encodeWithArchive:self]) {
      if (_failure == nil) {
        [self fail:@"-[%s encodeWithArchive:] couldn't write it", object_getClassName(object)];
      }
      return NO;
    }
    return [self close];
  }
  [self fail:@"%s can't be archived", object_getClassName(object)];
  return NO;
}

- (BOOL)encodeObject:(id)object asClass:(Class)cls forKey:(NXString *)key {
  Class actual = object == nil ? Nil : object_getClass(object);
  _class = (actual != cls && is_archiving(actual)) ? actual : Nil;
  BOOL encoded = [self encodeObject:object forKey:key];
  _class = Nil;
  return encoded;
}

///////////////////////////////////////////////////////////////////////////////
// DECODING

- (BOOL)containsKey:(NXString *)key {
  return [self read] && object_isKindOfClass(_current, [NXMap class]) &&
         [_current containsObject:key];
}

- (BOOL)decodeBoolForKey:(NXString *)key {
  NXNumber *number = [self numberForKey:key];
  if (number != nil && !object_isKindOfClass(number, [NXNumberBool class])) {
    [self fail:@"%@ isn't true or false", key];
    return NO;
  }
  return number != nil && [number boolValue];
}

- (int32_t)decodeInt32ForKey:(NXString *)key {
  BOOL negative;
  uint64_t magnitude;
  if (![self integerForKey:key negative:&negative magnitude:&magnitude]) {
    return 0;
  }
  if (negative ? magnitude > (uint64_t)INT32_MAX + 1 : magnitude > INT32_MAX) {
    [self fail:@"%@ is out of range", key];
    return 0;
  }
  return negative ? (int32_t)(0 - (int64_t)magnitude) : (int32_t)magnitude;
}

- (int64_t)decodeInt64ForKey:(NXString *)key {
  BOOL negative;
  uint64_t magnitude;
  if (![self integerForKey:key negative:&negative magnitude:&magnitude]) {
    return 0;
  }
  if (negative ? magnitude > (uint64_t)INT64_MAX + 1 : magnitude > INT64_MAX) {
    [self fail:@"%@ is out of range", key];
    return 0;
  }
  return negative ? (int64_t)(0 - magnitude) : (int64_t)magnitude;
}

- (uint32_t)decodeUnsignedInt32ForKey:(NXString *)key {
  BOOL negative;
  uint64_t magnitude;
  if (![self integerForKey:key negative:&negative magnitude:&magnitude]) {
    return 0;
  }
  if (negative || magnitude > UINT32_MAX) {
    [self fail:@"%@ is out of range", key];
    return 0;
  }
  return (uint32_t)magnitude;
}

- (uint64_t)decodeUnsignedInt64ForKey:(NXString *)key {
  BOOL negative;
  uint64_t magnitude;
  if (![self integerForKey:key negative:&negative magnitude:&magnitude]) {
    return 0;
  }
  if (negative) {
    [self fail:@"%@ is out of range", key];
    return 0;
  }
  return magnitude;
}

- (float)decodeFloat32ForKey:(NXString *)key {
  return (float)[self decodeFloat64ForKey:key];
}

- (double)decodeFloat64ForKey:(NXString *)key {
  NXNumber *number = [self numberForKey:key];
  if (number != nil && object_isKindOfClass(number, [NXNumberBool class])) {
    [self fail:@"%@ isn't a number", key];
    return 0;
  }
  return number == nil ? 0 : [number float64Value];
}

- (id)decodeObjectOfClass:(Class)cls forKey:(NXString *)key {
  id value = [self valueForKey:key];
  return value == nil ? nil : [self convert:value toClass:cls key:key];
}

- (NXArray *)decodeArrayOfClass:(Class)cls forKey:(NXString *)key {
  id value = [self valueForKey:key];
  if (value == nil) {
    return nil;
  }
  if (!object_isKindOfClass(value, [NXArray class])) {
    [self fail:@"%@ isn't an array", key];
    return nil;
  }
  NXArray *array = [NXArray arrayWithCapacity:[value count]];
  for (id element in (NXArray *)value) {
    id object = element == [NXNull nullValue] ? element : [self convert:element toClass:cls key:key];
    if (object == nil || ![array appendObject:object]) {
      if (_failure == nil) {
        [self fail:@"not enough memory for %@", key];
      }
      return nil;
    }
  }
  return array;
}

- (NXMap *)decodeMapOfClass:(Class)cls forKey:(NXString *)key {
  id value = [self valueForKey:key];
  if (value == nil) {
    return nil;
  }
  if (!object_isKindOfClass(value, [NXMap class])) {
    [self fail:@"%@ isn't a map", key];
    return nil;
  }
  NXMap *map = [NXMap mapWithCapacity:[value count]];
  for (NXString *k in (NXMap *)value) {
    id element = [value objectForKey:k];
    id object = element == [NXNull nullValue] ? element : [self convert:element toClass:cls key:k];
    if (object == nil || ![map setObject:object forKey:k]) {
      if (_failure == nil) {
        [self fail:@"not enough memory for %@", key];
      }
      return nil;
    }
  }
  return map;
}

@end

@implementation NXArchive (Private)

- (id)initWithStream:(NXStream *)stream encoding:(BOOL)encoding indent:(unsigned)indent {
  self = [super init];
  if (self != nil) {
    _stream = [stream retain];
    _encoding = encoding;
    _indent = indent;
    _maxDepth = DEPTH_DEFAULT;
    _maxLength = SIZE_MAX;
    if (stream == nil) {
      [self fail:@"there's no stream"];
    }
  }
  return self;
}

// Records the first error
- (void)fail:(NXString *)format, ... {
  if (_failure != nil) {
    return;
  }
  va_list args;
  va_start(args, format);
  _failure = [[NXString alloc] initWithFormat:format arguments:args];
  va_end(args);
  if (_failure == nil) {
    _failure = [@"not enough memory" retain];
  }
}

///////////////////////////////////////////////////////////////////////////////
// WRITING

- (BOOL)write:(const char *)bytes length:(size_t)length {
  if (_failure != nil) {
    return NO;
  }
  if ([_stream writeBytes:bytes length:length] != length) {
    [self fail:@"couldn't write to the stream"];
    return NO;
  }
  return YES;
}

- (BOOL)writeCString:(const char *)cStr {
  return [self write:cStr length:strlen(cStr)];
}

// Writes a string in quotes, with what JSON has to escape escaped
- (BOOL)writeQuoted:(NXString *)string {
  const char *s = [string cStr];
  size_t length = [string length];
  if (![self write:"\"" length:1]) {
    return NO;
  }
  size_t start = 0;
  for (size_t i = 0; i < length; i++) {
    unsigned char c = (unsigned char)s[i];
    const char *escape = NULL;
    char hex[7];
    switch (c) {
    case '"': escape = "\\\""; break;
    case '\\': escape = "\\\\"; break;
    case '\b': escape = "\\b"; break;
    case '\f': escape = "\\f"; break;
    case '\n': escape = "\\n"; break;
    case '\r': escape = "\\r"; break;
    case '\t': escape = "\\t"; break;
    default:
      if (c < 0x20) {
        sys_sprintf(hex, sizeof(hex), "\\u%04x", (unsigned)c);
        escape = hex;
      }
    }
    if (escape != NULL) {
      if (![self write:s + start length:i - start] || ![self writeCString:escape]) {
        return NO;
      }
      start = i + 1;
    }
  }
  return [self write:s + start length:length - start] && [self write:"\"" length:1];
}

- (BOOL)writeIndent {
  if (_indent == 0) {
    return YES;
  }
  if (![self write:"\n" length:1]) {
    return NO;
  }
  for (unsigned i = 0; i < _indent * _depth; i++) {
    if (![self write:" " length:1]) {
      return NO;
    }
  }
  return YES;
}

// Starts a value: in an object, after a comma and its key; in an array, after a
// comma; at the top, as the only one
- (BOOL)beginValueForKey:(NXString *)key {
  if (_failure != nil) {
    return NO;
  }
  if (!_encoding) {
    [self fail:@"it's a decoder"];
    return NO;
  }
  if (_levels == NULL) {
    _levels = sys_calloc(_maxDepth + 1, sizeof(level_t));
    if (_levels == NULL) {
      [self fail:@"not enough memory"];
      return NO;
    }
  }
  level_t *level = &((level_t *)_levels)[_depth];
  if (level->kind == 0) {
    if (level->count > 0) {
      [self fail:@"there's only one value in an archive, at the top"];
      return NO;
    }
    level->count++;
    return YES;
  }
  if (level->count > 0 && ![self write:"," length:1]) {
    return NO;
  }
  level->count++;
  if (![self writeIndent]) {
    return NO;
  }
  if (level->kind == '{') {
    if (key == nil) {
      [self fail:@"a value in an object needs a key"];
      return NO;
    }
    return [self writeQuoted:key] && [self writeCString:_indent > 0 ? ": " : ":"];
  }
  return YES;
}

- (BOOL)open:(char)kind {
  if (_depth >= _maxDepth) {
    [self fail:@"objects are nested more than %u deep", _maxDepth];
    return NO;
  }
  if (![self write:&kind length:1]) {
    return NO;
  }
  _depth++;
  level_t *level = &((level_t *)_levels)[_depth];
  level->kind = kind;
  level->count = 0;
  return YES;
}

- (BOOL)close {
  level_t *level = &((level_t *)_levels)[_depth];
  char kind = level->kind == '{' ? '}' : ']';
  BOOL any = level->count > 0;
  _depth--;
  if (any && ![self writeIndent]) {
    return NO;
  }
  if (![self write:&kind length:1]) {
    return NO;
  }
  if (_depth == 0 && _indent > 0) {
    return [self write:"\n" length:1];
  }
  return YES;
}

- (BOOL)encodeNumber:(NXNumber *)number forKey:(NXString *)key {
  if (object_isKindOfClass(number, [NXNumberBool class])) {
    return [self encodeBool:[number boolValue] forKey:key];
  }
  if (object_isKindOfClass(number, [NXNumberFloat32 class])) {
    return [self encodeFloat32:[number float32Value] forKey:key];
  }
  if ([number isFloat]) {
    return [self encodeFloat64:[number float64Value] forKey:key];
  }
  uint64_t magnitude;
  if ([number isNegative:&magnitude]) {
    return [self encodeInt64:(int64_t)(0 - magnitude) forKey:key];
  }
  return [self encodeUnsignedInt64:magnitude forKey:key];
}

///////////////////////////////////////////////////////////////////////////////
// READING

// Reads the whole stream the first time, and returns NO if the archive has failed
- (BOOL)read {
  if (_encoding) {
    if (_failure == nil) {
      [self fail:@"it's an encoder"];
    }
    return NO;
  }
  if (!_read) {
    _read = YES;
    NXScanner *scanner =
        [[NXScanner alloc] initWithStream:_stream
                                    flags:NXScannerQuotesDouble | NXScannerNumbersFloat |
                                          NXScannerKeywords];
    if (scanner == nil) {
      [self fail:@"not enough memory"];
    } else if (_failure == nil) {
      if (![self nextToken:scanner]) {
        [self fail:@"there's nothing to read"];
      } else {
        _root = [[self parseValue:scanner depth:0] retain];
        if (_failure == nil && [self nextToken:scanner]) {
          [self fail:@"there's more after the value, at %u", (unsigned)[scanner tokenPosition]];
        }
      }
    }
    [scanner release];
    _current = _root;
  }
  return _failure == nil;
}

// Moves to the next token which isn't space, or returns NO at the end
- (BOOL)nextToken:(NXScanner *)scanner {
  while ([scanner next]) {
    NXScannerClass c = [scanner tokenClass];
    if (c != NXScannerClassSpace && c != NXScannerClassNewline) {
      return YES;
    }
  }
  return NO;
}

// Reads a value, whose first token the scanner is at
- (id)parseValue:(NXScanner *)scanner depth:(unsigned)depth {
  NXScannerClass c = [scanner tokenClass];
  NXString *token = [scanner token];
  unsigned position = (unsigned)[scanner tokenPosition];
  if (token == nil) {
    [self fail:@"not enough memory"];
    return nil;
  }
  const char *t = [token cStr];

  if (c == NXScannerClassString) {
    NXString *string = [NXString stringWithQuotedString:token];
    if (string == nil) {
      [self fail:@"a string isn't valid, at %u", position];
    } else if ([string length] > _maxLength) {
      [self fail:@"a string is longer than %u bytes, at %u", (unsigned)_maxLength, position];
      string = nil;
    }
    return string;
  }
  if (c == NXScannerClassNumber) {
    BOOL integer;
    size_t length = [token length];
    if (!is_json_number(t, length, &integer)) {
      [self fail:@"%@ isn't a number, at %u", token, position];
      return nil;
    }
    int64_t i;
    uint64_t u;
    double d;
    if (integer && sys_string_parse_int64(t, length, &i)) {
      return [NXNumber numberWithInt64:i];
    }
    if (integer && sys_string_parse_uint64(t, length, &u)) {
      return [NXNumber numberWithUnsignedInt64:u];
    }
    if (sys_string_parse_float64(t, length, &d) && d - d == 0) {
      return [NXNumber numberWithFloat64:d];
    }
    [self fail:@"%@ is out of range, at %u", token, position];
    return nil;
  }
  if (c == NXScannerClassKeyword || c == NXScannerClassAlpha) {
    if (strcmp(t, "true") == 0) {
      return [NXNumber trueValue];
    }
    if (strcmp(t, "false") == 0) {
      return [NXNumber falseValue];
    }
    if (strcmp(t, "null") == 0) {
      return [NXNull nullValue];
    }
  }
  if (c == NXScannerClassPunct && (t[0] == '[' || t[0] == '{')) {
    if (depth >= _maxDepth) {
      [self fail:@"objects are nested more than %u deep, at %u", _maxDepth, position];
      return nil;
    }
    BOOL isMap = t[0] == '{';
    char end = isMap ? '}' : ']';
    id container = isMap ? (id)[NXMap map] : (id)[NXArray array];
    if (container == nil || ![self nextToken:scanner]) {
      [self fail:container == nil ? @"not enough memory" : @"%c isn't closed", t[0]];
      return nil;
    }
    if ([scanner tokenClass] == NXScannerClassPunct && [[scanner token] cStr][0] == end) {
      return container;
    }
    for (;;) {
      NXString *key = nil;
      if (isMap) {
        if ([scanner tokenClass] != NXScannerClassString ||
            (key = [NXString stringWithQuotedString:[scanner token]]) == nil) {
          [self fail:@"a key isn't a string, at %u", (unsigned)[scanner tokenPosition]];
          return nil;
        }
        if (![self nextToken:scanner] || [scanner tokenClass] != NXScannerClassPunct ||
            [[scanner token] cStr][0] != ':') {
          [self fail:@"a key isn't followed by a colon, at %u", (unsigned)[scanner tokenPosition]];
          return nil;
        }
        if (![self nextToken:scanner]) {
          [self fail:@"%c isn't closed", t[0]];
          return nil;
        }
      }
      id value = [self parseValue:scanner depth:depth + 1];
      if (value == nil) {
        return nil;
      }
      if ([container count] >= _maxLength) {
        [self fail:@"an array or object has more than %u values, at %u", (unsigned)_maxLength,
                   position];
        return nil;
      }
      BOOL added = isMap ? [container setObject:value forKey:key] : [container appendObject:value];
      if (!added) {
        [self fail:@"not enough memory"];
        return nil;
      }
      if (![self nextToken:scanner] || [scanner tokenClass] != NXScannerClassPunct) {
        [self fail:@"%c isn't closed, at %u", t[0], position];
        return nil;
      }
      char next = [[scanner token] cStr][0];
      if (next == end) {
        return container;
      }
      if (next != ',' || ![self nextToken:scanner]) {
        [self fail:@"a comma is missing, at %u", (unsigned)[scanner tokenPosition]];
        return nil;
      }
    }
  }
  [self fail:@"%@ isn't a value, at %u", token, position];
  return nil;
}

///////////////////////////////////////////////////////////////////////////////
// DECODING

// The value for a key in the object being decoded, or the root for nil, or nil if
// there isn't one or it's null
- (id)valueForKey:(NXString *)key {
  if (![self read]) {
    return nil;
  }
  id value = _current;
  if (key != nil) {
    value = object_isKindOfClass(_current, [NXMap class]) ? [_current objectForKey:key] : nil;
  }
  return value == [NXNull nullValue] ? nil : value;
}

// Makes an object of a class from a value which was read
- (id)convert:(id)value toClass:(Class)cls key:(NXString *)key {
  if (_failure != nil) {
    return nil;
  }
  if (cls == Nil) {
    return [[value retain] autorelease];
  }
  if (is_subclass(cls, [NXData class])) {
    NXData *data = object_isKindOfClass(value, [NXString class])
                       ? [NXData dataWithBase64String:value]
                       : nil;
    if (data == nil) {
      [self fail:@"%@ isn't base64", key];
    }
    return data;
  }
  if (is_subclass(cls, [NXDate class])) {
    NXDate *date = object_isKindOfClass(value, [NXString class])
                       ? [NXDate dateWithString:value format:NXDateFormatISO8601]
                       : nil;
    if (date == nil) {
      [self fail:@"%@ isn't an ISO 8601 date", key];
    }
    return date;
  }
  if (is_archiving(cls)) {
    if (!object_isKindOfClass(value, [NXMap class])) {
      [self fail:@"%@ isn't an object, for %s", key, class_getName(cls)];
      return nil;
    }

    // A subclass, if it's named
    Class actual = cls;
    id name = [value objectForKey:@"@class"];
    if (name != nil) {
      actual = object_isKindOfClass(name, [NXString class]) ? objc_lookupClass([name cStr]) : Nil;
      if (actual == Nil || !is_subclass(actual, cls) || !is_archiving(actual)) {
        [self fail:@"%@ is a %@, which isn't a %s", key, name, class_getName(cls)];
        return nil;
      }
    }
    if (_depth >= _maxDepth) {
      [self fail:@"objects are nested more than %u deep", _maxDepth];
      return nil;
    }
    id outer = _current;
    _current = value;
    _depth++;
    id object = [[actual alloc] initWithArchive:self];
    _depth--;
    _current = outer;
    if (object == nil || _failure != nil) {
      [object release];
      if (_failure == nil) {
        [self fail:@"-[%s initWithArchive:] couldn't read %@", class_getName(actual), key];
      }
      return nil;
    }
    return [object autorelease];
  }
  if (!object_isKindOfClass(value, cls)) {
    [self fail:@"%@ is a %s, not a %s", key, object_getClassName(value), class_getName(cls)];
    return nil;
  }
  return [[value retain] autorelease];
}

- (NXNumber *)numberForKey:(NXString *)key {
  id value = [self valueForKey:key];
  if (value != nil && !object_isKindOfClass(value, [NXNumber class])) {
    [self fail:@"%@ isn't a number", key];
    return nil;
  }
  return value;
}

// An integer, as a sign and magnitude, or NO if there isn't one
- (BOOL)integerForKey:(NXString *)key
             negative:(BOOL *)negative
            magnitude:(uint64_t *)magnitude {
  NXNumber *number = [self numberForKey:key];
  if (number == nil) {
    return NO;
  }
  if (object_isKindOfClass(number, [NXNumberBool class])) {
    [self fail:@"%@ isn't an integer", key];
    return NO;
  }
  if ([number isFloat]) {
    if (NXFloatToInteger([number float64Value], negative, magnitude) != NXFloatExact) {
      [self fail:@"%@ isn't an integer", key];
      return NO;
    }
    return YES;
  }
  *negative = [number isNegative:magnitude];
  return YES;
}

@end
