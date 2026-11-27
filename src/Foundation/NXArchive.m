#include "NXNumber+Private.h"
#include "NXObject+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <runtime/gcc/runtime.h>
#include <float.h>
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

// The binary header, of a magic number and a version
static const char binary_header[4] = {'N', 'X', 'A', 1};

// The 32-bit FNV-1a hash of a name, which is the same on every platform
static uint32_t name_hash(const char *name) {
  uint32_t hash = 2166136261u;
  for (; *name != '\0'; name++) {
    hash ^= (uint8_t)*name;
    hash *= 16777619u;
  }
  return hash;
}

// The kinds of number in a binary archive
enum { NUMBER_BOOL, NUMBER_INT64, NUMBER_UINT64, NUMBER_FLOAT32, NUMBER_FLOAT64 };

// The classes which adopt NXArchiving, by the hashes of their names
typedef struct {
  uint32_t hash;
  Class cls;
} archive_class_t;

static archive_class_t *archive_classes = NULL;
static size_t archive_class_count = 0;

// The names of the classes which are archived as themselves, whose hashes can't be
// used by another
static const char *builtin_names[] = {"NXString", "NXNumber", "NXNull", "NXArray",
                                      "NXMap",    "NXData",   "NXDate"};

// Finds the classes which adopt NXArchiving, the first time, and panics if two of
// their names, or one and a built-in class's, have the same hash
static void find_archive_classes(void) {
  @synchronized([NXArchive class]) {
    if (archive_classes != NULL) {
      return;
    }
    size_t count = objc_getClassList(NULL, 0);
    Class *classes = sys_malloc(count * sizeof(Class));
    archive_class_t *found = sys_malloc((count + 1) * sizeof(archive_class_t));
    if (classes == NULL || found == NULL) {
      sys_panicf("NXArchive: not enough memory for the table of classes");
    }
    count = objc_getClassList(classes, count);
    size_t n = 0;
    for (size_t i = 0; i < count; i++) {
      if (!is_archiving(classes[i])) {
        continue;
      }
      uint32_t hash = name_hash(class_getName(classes[i]));
      if (hash == 0) {
        sys_panicf("NXArchive: the name of %s has a hash of zero", class_getName(classes[i]));
      }
      for (size_t j = 0; j < sizeof(builtin_names) / sizeof(builtin_names[0]); j++) {
        if (hash == name_hash(builtin_names[j])) {
          sys_panicf("NXArchive: %s has the same hash as %s", class_getName(classes[i]),
                     builtin_names[j]);
        }
      }
      for (size_t j = 0; j < n; j++) {
        if (found[j].hash == hash) {
          sys_panicf("NXArchive: %s has the same hash as %s", class_getName(classes[i]),
                     class_getName(found[j].cls));
        }
      }
      found[n].hash = hash;
      found[n].cls = classes[i];
      n++;
    }
    sys_free(classes);
    archive_class_count = n;
    archive_classes = found;
  }
}

static Class archive_class(uint32_t hash) {
  find_archive_classes();
  for (size_t i = 0; i < archive_class_count; i++) {
    if (archive_classes[i].hash == hash) {
      return archive_classes[i].cls;
    }
  }
  return Nil;
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
- (id)initWithStream:(NXStream *)stream
              format:(NXArchiveFormat)format
            encoding:(BOOL)encoding
              indent:(unsigned)indent;
- (BOOL)beginBinary;
- (BOOL)writeLittle:(uint64_t)value size:(unsigned)size;
- (BOOL)writeVarint:(uint64_t)value;
- (BOOL)writeHash:(const char *)name;
- (BOOL)encodeBinaryObject:(id)object;
- (BOOL)readLittle:(uint64_t *)value size:(unsigned)size;
- (BOOL)readVarint:(uint64_t *)value;
- (BOOL)readLength:(size_t *)length;
- (id)decodeBinaryObjectOfClass:(Class)cls;
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
  return [[[self alloc] initWithStream:stream
                                format:NXArchiveFormatJSON
                              encoding:YES
                                indent:indent] autorelease];
}

+ (id)JSONDecoderWithStream:(NXStream *)stream {
  return [[[self alloc] initWithStream:stream
                                format:NXArchiveFormatJSON
                              encoding:NO
                                indent:0] autorelease];
}

+ (id)binaryEncoderWithStream:(NXStream *)stream {
  return [[[self alloc] initWithStream:stream
                                format:NXArchiveFormatBinary
                              encoding:YES
                                indent:0] autorelease];
}

+ (id)binaryDecoderWithStream:(NXStream *)stream {
  return [[[self alloc] initWithStream:stream
                                format:NXArchiveFormatBinary
                              encoding:NO
                                indent:0] autorelease];
}

+ (BOOL)encodeObject:(id)object toStream:(NXStream *)stream format:(NXArchiveFormat)format {
  NXArchive *archive = format == NXArchiveFormatBinary
                           ? [self binaryEncoderWithStream:stream]
                           : [self JSONEncoderWithStream:stream indent:0];
  return archive != nil && [archive encodeObject:object forKey:nil];
}

+ (id)decodeObjectOfClass:(Class)cls
               fromStream:(NXStream *)stream
                   format:(NXArchiveFormat)format {
  NXArchive *archive = format == NXArchiveFormatBinary ? [self binaryDecoderWithStream:stream]
                                                       : [self JSONDecoderWithStream:stream];
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
  return _format;
}

- (BOOL)isEncoding {
  return _encoding;
}

- (BOOL)failed {
  if (!_encoding && _format == NXArchiveFormatJSON) {
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
  if (_format == NXArchiveFormatBinary) {
    return [self beginBinary] && [self writeLittle:value ? 1 : 0 size:1];
  }
  return [self beginValueForKey:key] && [self writeCString:value ? "true" : "false"];
}

- (BOOL)encodeInt32:(int32_t)value forKey:(NXString *)key {
  if (_format == NXArchiveFormatBinary) {
    return [self beginBinary] && [self writeLittle:(uint32_t)value size:4];
  }
  return [self encodeInt64:value forKey:key];
}

- (BOOL)encodeInt64:(int64_t)value forKey:(NXString *)key {
  if (_format == NXArchiveFormatBinary) {
    return [self beginBinary] && [self writeLittle:(uint64_t)value size:8];
  }
  char buffer[32];
  sys_sprintf(buffer, sizeof(buffer), "%ld", value);
  return [self beginValueForKey:key] && [self writeCString:buffer];
}

- (BOOL)encodeUnsignedInt32:(uint32_t)value forKey:(NXString *)key {
  if (_format == NXArchiveFormatBinary) {
    return [self beginBinary] && [self writeLittle:value size:4];
  }
  return [self encodeUnsignedInt64:value forKey:key];
}

- (BOOL)encodeUnsignedInt64:(uint64_t)value forKey:(NXString *)key {
  if (_format == NXArchiveFormatBinary) {
    return [self beginBinary] && [self writeLittle:value size:8];
  }
  char buffer[32];
  sys_sprintf(buffer, sizeof(buffer), "%lu", value);
  return [self beginValueForKey:key] && [self writeCString:buffer];
}

- (BOOL)encodeFloat32:(float)value forKey:(NXString *)key {
  if (_format == NXArchiveFormatBinary) {
    uint32_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return [self beginBinary] && [self writeLittle:bits size:4];
  }
  if (value != value || value - value != 0) {
    [self fail:@"%@ isn't a finite number, which JSON can't have", key];
    return NO;
  }
  char buffer[32];
  sys_sprintf(buffer, sizeof(buffer), "%.9g", (double)value);
  return [self beginValueForKey:key] && [self writeCString:buffer];
}

- (BOOL)encodeFloat64:(double)value forKey:(NXString *)key {
  if (_format == NXArchiveFormatBinary) {
    uint64_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return [self beginBinary] && [self writeLittle:bits size:8];
  }
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
  if (!_encoding) {
    [self fail:@"it's a decoder"];
  }
  if (_failure != nil) {
    return NO;
  }
  if (_format == NXArchiveFormatBinary) {
    return [self beginBinary] && [self encodeBinaryObject:object];
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
  if (_format == NXArchiveFormatBinary) {
    return [self encodeObject:object forKey:key]; // the class is always written
  }
  Class actual = object == nil ? Nil : object_getClass(object);
  _class = (actual != cls && is_archiving(actual)) ? actual : Nil;
  BOOL encoded = [self encodeObject:object forKey:key];
  _class = Nil;
  return encoded;
}

///////////////////////////////////////////////////////////////////////////////
// DECODING

- (BOOL)containsKey:(NXString *)key {
  if (_format == NXArchiveFormatBinary) {
    return _failure == nil;
  }
  return [self read] && object_isKindOfClass(_current, [NXMap class]) &&
         [_current containsObject:key];
}

- (BOOL)decodeBoolForKey:(NXString *)key {
  if (_format == NXArchiveFormatBinary) {
    uint64_t value = 0;
    if ([self beginBinary] && [self readLittle:&value size:1] && value > 1) {
      [self fail:@"%@ isn't true or false", key];
    }
    return _failure == nil && value == 1;
  }
  NXNumber *number = [self numberForKey:key];
  if (number != nil && !object_isKindOfClass(number, [NXNumberBool class])) {
    [self fail:@"%@ isn't true or false", key];
    return NO;
  }
  return number != nil && [number boolValue];
}

- (int32_t)decodeInt32ForKey:(NXString *)key {
  if (_format == NXArchiveFormatBinary) {
    uint64_t value = 0;
    return [self beginBinary] && [self readLittle:&value size:4] ? (int32_t)(uint32_t)value : 0;
  }
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
  if (_format == NXArchiveFormatBinary) {
    uint64_t value = 0;
    return [self beginBinary] && [self readLittle:&value size:8] ? (int64_t)value : 0;
  }
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
  if (_format == NXArchiveFormatBinary) {
    uint64_t value = 0;
    return [self beginBinary] && [self readLittle:&value size:4] ? (uint32_t)value : 0;
  }
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
  if (_format == NXArchiveFormatBinary) {
    uint64_t value = 0;
    return [self beginBinary] && [self readLittle:&value size:8] ? value : 0;
  }
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
  if (_format == NXArchiveFormatBinary) {
    uint64_t value = 0;
    if (![self beginBinary] || ![self readLittle:&value size:4]) {
      return 0;
    }
    uint32_t bits = (uint32_t)value;
    float f;
    memcpy(&f, &bits, sizeof(f));
    return f;
  }
  double value = [self decodeFloat64ForKey:key];
  if (value > FLT_MAX || value < -FLT_MAX) {
    [self fail:@"%@ is out of range", key];
    return 0;
  }
  return (float)value;
}

- (double)decodeFloat64ForKey:(NXString *)key {
  if (_format == NXArchiveFormatBinary) {
    uint64_t bits = 0;
    if (![self beginBinary] || ![self readLittle:&bits size:8]) {
      return 0;
    }
    double d;
    memcpy(&d, &bits, sizeof(d));
    return d;
  }
  NXNumber *number = [self numberForKey:key];
  if (number != nil && object_isKindOfClass(number, [NXNumberBool class])) {
    [self fail:@"%@ isn't a number", key];
    return 0;
  }
  return number == nil ? 0 : [number float64Value];
}

- (id)decodeObjectOfClass:(Class)cls forKey:(NXString *)key {
  if (_format == NXArchiveFormatBinary) {
    return [self beginBinary] ? [self decodeBinaryObjectOfClass:cls] : nil;
  }
  id value = [self valueForKey:key];
  return value == nil ? nil : [self convert:value toClass:cls key:key];
}

- (NXArray *)decodeArrayOfClass:(Class)cls forKey:(NXString *)key {
  if (_format == NXArchiveFormatBinary) {
    uint64_t hash = 0;
    if (![self beginBinary] || ![self readLittle:&hash size:4] || hash == 0) {
      return nil;
    }
    size_t count;
    if (hash != name_hash("NXArray")) {
      [self fail:@"%@ isn't an array", key];
      return nil;
    }
    if (![self readLength:&count]) {
      return nil;
    }
    NXArray *array = [NXArray arrayWithCapacity:count];
    for (size_t i = 0; i < count && _failure == nil; i++) {
      id object = [self decodeBinaryObjectOfClass:cls];
      if (_failure == nil && ![array appendObject:object == nil ? [NXNull nullValue] : object]) {
        [self fail:@"not enough memory for %@", key];
      }
    }
    return _failure == nil ? array : nil;
  }
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
  if (_format == NXArchiveFormatBinary) {
    uint64_t hash = 0;
    if (![self beginBinary] || ![self readLittle:&hash size:4] || hash == 0) {
      return nil;
    }
    size_t count;
    if (hash != name_hash("NXMap")) {
      [self fail:@"%@ isn't a map", key];
      return nil;
    }
    if (![self readLength:&count]) {
      return nil;
    }
    NXMap *map = [NXMap mapWithCapacity:count];
    for (size_t i = 0; i < count && _failure == nil; i++) {
      id k = [self decodeBinaryObjectOfClass:Nil];
      id object = [self decodeBinaryObjectOfClass:cls];
      if (_failure == nil && (k == nil || ![map setObject:object == nil ? [NXNull nullValue] : object
                                                  forKey:k])) {
        [self fail:k == nil ? @"a key in %@ is nil" : @"not enough memory for %@", key];
      }
    }
    return _failure == nil ? map : nil;
  }
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

- (id)initWithStream:(NXStream *)stream
              format:(NXArchiveFormat)format
            encoding:(BOOL)encoding
              indent:(unsigned)indent {
  self = [super init];
  if (self != nil) {
    _stream = [stream retain];
    _format = format;
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
        if ([key length] > _maxLength) {
          [self fail:@"a key is longer than %u bytes, at %u", (unsigned)_maxLength,
                     (unsigned)[scanner tokenPosition]];
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

///////////////////////////////////////////////////////////////////////////////
// BINARY

// Starts a value: the header comes first, and there's only one value at the top
- (BOOL)beginBinary {
  if (_failure != nil) {
    return NO;
  }
  if (_depth == 0) {
    if (_top) {
      [self fail:@"there's only one value in an archive, at the top"];
      return NO;
    }
    _top = YES;
    if (_encoding) {
      return [self write:binary_header length:sizeof(binary_header)];
    }
    char header[sizeof(binary_header)];
    if ([_stream readBytes:header length:sizeof(header)] != sizeof(header) ||
        memcmp(header, binary_header, sizeof(header)) != 0) {
      [self fail:@"it isn't a binary archive of this version"];
      return NO;
    }
  }
  return YES;
}

- (BOOL)writeLittle:(uint64_t)value size:(unsigned)size {
  char bytes[8];
  for (unsigned i = 0; i < size; i++) {
    bytes[i] = (char)(value >> (8 * i));
  }
  return [self write:bytes length:size];
}

// Writes a number in as few bytes as it needs: seven bits in each, with the top bit
// set in all but the last
- (BOOL)writeVarint:(uint64_t)value {
  char bytes[10];
  unsigned n = 0;
  do {
    bytes[n] = (char)(value & 0x7F);
    value >>= 7;
    if (value != 0) {
      bytes[n] |= (char)0x80;
    }
    n++;
  } while (value != 0);
  return [self write:bytes length:n];
}

- (BOOL)writeHash:(const char *)name {
  return [self writeLittle:name_hash(name) size:4];
}

- (BOOL)encodeBinaryObject:(id)object {
  if (object == nil) {
    return [self writeLittle:0 size:4];
  }
  if (object == [NXNull nullValue]) {
    return [self writeHash:"NXNull"];
  }
  if (object_isKindOfClass(object, [NXString class])) {
    size_t length = [object length];
    return [self writeHash:"NXString"] && [self writeVarint:length] &&
           [self write:[object cStr] length:length];
  }
  if (object_isKindOfClass(object, [NXData class])) {
    size_t length = [object length];
    return [self writeHash:"NXData"] && [self writeVarint:length] &&
           (length == 0 || [self write:[object bytes] length:length]);
  }
  if (object_isKindOfClass(object, [NXDate class])) {
    return [self writeHash:"NXDate"] &&
           [self writeLittle:(uint64_t)[object seconds] size:8] &&
           [self writeLittle:(uint32_t)[object nanoseconds] size:4] &&
           [self writeLittle:(uint32_t)[object timeZoneOffset] size:4];
  }
  if (object_isKindOfClass(object, [NXNumber class])) {
    if (![self writeHash:"NXNumber"]) {
      return NO;
    }
    if (object_isKindOfClass(object, [NXNumberBool class])) {
      return [self writeLittle:NUMBER_BOOL size:1] &&
             [self writeLittle:[object boolValue] ? 1 : 0 size:1];
    }
    if (object_isKindOfClass(object, [NXNumberFloat32 class])) {
      float f = [object float32Value];
      uint32_t bits;
      memcpy(&bits, &f, sizeof(bits));
      return [self writeLittle:NUMBER_FLOAT32 size:1] && [self writeLittle:bits size:4];
    }
    if ([object isFloat]) {
      double d = [object float64Value];
      uint64_t bits;
      memcpy(&bits, &d, sizeof(bits));
      return [self writeLittle:NUMBER_FLOAT64 size:1] && [self writeLittle:bits size:8];
    }
    uint64_t magnitude;
    if ([object isNegative:&magnitude]) {
      return [self writeLittle:NUMBER_INT64 size:1] && [self writeLittle:0 - magnitude size:8];
    }
    return [self writeLittle:NUMBER_UINT64 size:1] && [self writeLittle:magnitude size:8];
  }

  // Containers and objects of other classes are nested
  BOOL isArray = object_isKindOfClass(object, [NXArray class]);
  BOOL isMap = object_isKindOfClass(object, [NXMap class]);
  if (!isArray && !isMap && !is_archiving(object_getClass(object))) {
    [self fail:@"%s can't be archived", object_getClassName(object)];
    return NO;
  }
  if (_depth >= _maxDepth) {
    [self fail:@"objects are nested more than %u deep", _maxDepth];
    return NO;
  }
  _depth++;
  BOOL encoded;
  if (isArray) {
    encoded = [self writeHash:"NXArray"] && [self writeVarint:[object count]];
    for (id element in (NXArray *)object) {
      if (!encoded) {
        break;
      }
      encoded = [self encodeBinaryObject:element];
    }
  } else if (isMap) {
    encoded = [self writeHash:"NXMap"] && [self writeVarint:[object count]];
    for (id k in (NXMap *)object) {
      if (!encoded) {
        break;
      }
      encoded = [self encodeBinaryObject:k] && [self encodeBinaryObject:[object objectForKey:k]];
    }
  } else {
    encoded = [self writeHash:object_getClassName(object)] && [object encodeWithArchive:self];
    if (!encoded && _failure == nil) {
      [self fail:@"-[%s encodeWithArchive:] couldn't write it", object_getClassName(object)];
    }
  }
  _depth--;
  return encoded && _failure == nil;
}

- (BOOL)readLittle:(uint64_t *)value size:(unsigned)size {
  if (_failure != nil) {
    return NO;
  }
  uint8_t bytes[8];
  if ([_stream readBytes:bytes length:size] != size) {
    [self fail:@"the archive ends early"];
    return NO;
  }
  *value = 0;
  for (unsigned i = 0; i < size; i++) {
    *value |= (uint64_t)bytes[i] << (8 * i);
  }
  return YES;
}

- (BOOL)readVarint:(uint64_t *)value {
  *value = 0;
  for (unsigned shift = 0; shift < 64; shift += 7) {
    uint64_t byte;
    if (![self readLittle:&byte size:1]) {
      return NO;
    }
    if (shift == 63 && byte > 1) {
      break;
    }
    *value |= (byte & 0x7F) << shift;
    if ((byte & 0x80) == 0) {
      return YES;
    }
  }
  [self fail:@"a length is too long"];
  return NO;
}

// Reads the length of a string, data, array or map, which can't be more than the
// maximum
- (BOOL)readLength:(size_t *)length {
  uint64_t value;
  if (![self readVarint:&value]) {
    return NO;
  }
  if (value > _maxLength || value > SIZE_MAX) {
    [self fail:@"a string, data, array or map is longer than the maximum"];
    return NO;
  }
  *length = (size_t)value;
  return YES;
}

// Reads an object, which is of a class or a subclass of it, or anything if it's Nil
- (id)decodeBinaryObjectOfClass:(Class)cls {
  uint64_t hash;
  if (![self readLittle:&hash size:4]) {
    return nil;
  }
  if (hash == 0) {
    return nil;
  }
  id object = nil;
  if (hash == name_hash("NXNull")) {
    // Null is nil, when a class is expected, as it is in JSON
    return cls == Nil || cls == [NXNull class] ? [NXNull nullValue] : nil;
  } else if (hash == name_hash("NXString") || hash == name_hash("NXData")) {
    size_t length;
    if (![self readLength:&length]) {
      return nil;
    }
    char *bytes = length == 0 ? NULL : sys_malloc(length);
    if (length > 0 && bytes == NULL) {
      [self fail:@"not enough memory"];
      return nil;
    }
    if (length > 0 && [_stream readBytes:bytes length:length] != length) {
      [self fail:@"the archive ends early"];
    } else if (hash == name_hash("NXString")) {
      object = [[[NXString alloc] initWithBytes:bytes length:length] autorelease];
    } else {
      object = [NXData dataWithBytes:bytes length:length];
    }
    sys_free(bytes);
  } else if (hash == name_hash("NXDate")) {
    uint64_t seconds, nanoseconds, offset;
    if ([self readLittle:&seconds size:8] && [self readLittle:&nanoseconds size:4] &&
        [self readLittle:&offset size:4]) {
      if ((int32_t)nanoseconds < 0 || nanoseconds >= 1000000000) {
        [self fail:@"a date isn't valid"];
      } else {
        object = [[NXDate dateWithSeconds:(int64_t)seconds nanoseconds:(int32_t)nanoseconds]
            dateWithTimeZoneOffset:(int32_t)(uint32_t)offset];
      }
    }
  } else if (hash == name_hash("NXNumber")) {
    uint64_t kind, value;
    if ([self readLittle:&kind size:1]) {
      switch (kind) {
      case NUMBER_BOOL:
        if ([self readLittle:&value size:1]) {
          object = value == 0 ? [NXNumber falseValue] : [NXNumber trueValue];
        }
        break;
      case NUMBER_INT64:
        if ([self readLittle:&value size:8]) {
          object = [NXNumber numberWithInt64:(int64_t)value];
        }
        break;
      case NUMBER_UINT64:
        if ([self readLittle:&value size:8]) {
          object = [NXNumber numberWithUnsignedInt64:value];
        }
        break;
      case NUMBER_FLOAT32:
        if ([self readLittle:&value size:4]) {
          uint32_t bits = (uint32_t)value;
          float f;
          memcpy(&f, &bits, sizeof(f));
          object = [NXNumber numberWithFloat32:f];
        }
        break;
      case NUMBER_FLOAT64:
        if ([self readLittle:&value size:8]) {
          double d;
          memcpy(&d, &value, sizeof(d));
          object = [NXNumber numberWithFloat64:d];
        }
        break;
      default:
        [self fail:@"a number isn't valid"];
      }
    }
  } else {
    // Nested: an array, a map, or an object of a class which adopts NXArchiving
    BOOL isArray = hash == name_hash("NXArray");
    BOOL isMap = hash == name_hash("NXMap");
    Class actual = isArray ? [NXArray class] : isMap ? [NXMap class] : archive_class((uint32_t)hash);
    if (actual == Nil) {
      [self fail:@"an object is of a class which isn't known"];
      return nil;
    }
    if (cls != Nil && !is_subclass(actual, cls)) {
      [self fail:@"an object is a %s, not a %s", class_getName(actual), class_getName(cls)];
      return nil;
    }
    if (_depth >= _maxDepth) {
      [self fail:@"objects are nested more than %u deep", _maxDepth];
      return nil;
    }
    _depth++;
    if (isArray || isMap) {
      size_t count;
      if ([self readLength:&count]) {
        id container = isArray ? (id)[NXArray arrayWithCapacity:count]
                               : (id)[NXMap mapWithCapacity:count];
        for (size_t i = 0; i < count && _failure == nil; i++) {
          id k = isMap ? [self decodeBinaryObjectOfClass:Nil] : nil;
          id element = [self decodeBinaryObjectOfClass:Nil];
          if (_failure != nil) {
            break;
          }
          element = element == nil ? [NXNull nullValue] : element;
          BOOL added = isArray ? [container appendObject:element]
                               : (k != nil && [container setObject:element forKey:k]);
          if (!added) {
            [self fail:k == nil && isMap ? @"a key is nil" : @"not enough memory"];
          }
        }
        object = _failure == nil ? container : nil;
      }
    } else {
      object = [[[actual alloc] initWithArchive:self] autorelease];
      if (object == nil && _failure == nil) {
        [self fail:@"-[%s initWithArchive:] couldn't read it", class_getName(actual)];
      }
    }
    _depth--;
    return _failure == nil ? object : nil;
  }
  if (object == nil || _failure != nil) {
    return nil;
  }
  if (cls != Nil && !object_isKindOfClass(object, cls)) {
    [self fail:@"an object is a %s, not a %s", object_getClassName(object), class_getName(cls)];
    return nil;
  }
  return object;
}

@end
