// Archiving objects as binary
#include <Foundation/Foundation.h>
#include <string.h>
#include <test/test.h>

@interface Point : NXObject <NXArchiving> {
@public
  int32_t x, y;
}
@end

@implementation Point
- (BOOL)encodeWithArchive:(NXArchive *)archive {
  return [archive encodeInt32:x forKey:@"x"] && [archive encodeInt32:y forKey:@"y"];
}
- (id)initWithArchive:(NXArchive *)archive {
  self = [super init];
  x = [archive decodeInt32ForKey:@"x"];
  y = [archive decodeInt32ForKey:@"y"];
  return self;
}
@end

@interface Point3 : Point {
@public
  int32_t z;
}
@end

@implementation Point3
- (BOOL)encodeWithArchive:(NXArchive *)archive {
  return [super encodeWithArchive:archive] && [archive encodeInt32:z forKey:@"z"];
}
- (id)initWithArchive:(NXArchive *)archive {
  self = [super initWithArchive:archive];
  z = [archive decodeInt32ForKey:@"z"];
  return self;
}
@end

// Every kind of value, in order
@interface Everything : NXObject <NXArchiving> {
@public
  BOOL b;
  int32_t i32;
  int64_t i64;
  uint32_t u32;
  uint64_t u64;
  float f32;
  double f64;
  NXString *string;
  NXData *data;
  NXDate *date;
  Point *point;
  NXArray *points;
  NXMap *map;
  id any;
  id none;
}
@end

@implementation Everything
- (void)dealloc {
  [string release];
  [data release];
  [date release];
  [point release];
  [points release];
  [map release];
  [any release];
  [super dealloc];
}
- (BOOL)encodeWithArchive:(NXArchive *)archive {
  return [archive encodeBool:b forKey:@"b"] && [archive encodeInt32:i32 forKey:@"i32"] &&
         [archive encodeInt64:i64 forKey:@"i64"] &&
         [archive encodeUnsignedInt32:u32 forKey:@"u32"] &&
         [archive encodeUnsignedInt64:u64 forKey:@"u64"] &&
         [archive encodeFloat32:f32 forKey:@"f32"] && [archive encodeFloat64:f64 forKey:@"f64"] &&
         [archive encodeObject:string forKey:@"string"] &&
         [archive encodeObject:data forKey:@"data"] && [archive encodeObject:date forKey:@"date"] &&
         [archive encodeObject:point forKey:@"point"] &&
         [archive encodeObject:points forKey:@"points"] &&
         [archive encodeObject:map forKey:@"map"] && [archive encodeObject:any forKey:@"any"] &&
         [archive encodeObject:none forKey:@"none"];
}
- (id)initWithArchive:(NXArchive *)archive {
  self = [super init];
  b = [archive decodeBoolForKey:@"b"];
  i32 = [archive decodeInt32ForKey:@"i32"];
  i64 = [archive decodeInt64ForKey:@"i64"];
  u32 = [archive decodeUnsignedInt32ForKey:@"u32"];
  u64 = [archive decodeUnsignedInt64ForKey:@"u64"];
  f32 = [archive decodeFloat32ForKey:@"f32"];
  f64 = [archive decodeFloat64ForKey:@"f64"];
  string = [[archive decodeObjectOfClass:[NXString class] forKey:@"string"] retain];
  data = [[archive decodeObjectOfClass:[NXData class] forKey:@"data"] retain];
  date = [[archive decodeObjectOfClass:[NXDate class] forKey:@"date"] retain];
  point = [[archive decodeObjectOfClass:[Point class] forKey:@"point"] retain];
  points = [[archive decodeArrayOfClass:[Point class] forKey:@"points"] retain];
  map = [[archive decodeMapOfClass:Nil forKey:@"map"] retain];
  any = [[archive decodeObjectOfClass:Nil forKey:@"any"] retain];
  none = [archive decodeObjectOfClass:[NXString class] forKey:@"none"];
  if ([archive failed]) {
    [self release];
    return nil;
  }
  return self;
}
@end

// Archives an object, and returns its bytes
static NXData *binary(id object) {
  NXStream *stream = [NXStream streamWithCapacity:1024];
  test_assert(stream != nil);
  BOOL encoded = [NXArchive encodeObject:object toStream:stream format:NXArchiveFormatBinary];
  NXData *data = nil;
  if (encoded) {
    size_t length = [stream position];
    test_assert([stream seek:0 relative:NO]);
    uint8_t bytes[1024];
    test_assert([stream readBytes:bytes length:length] == length);
    data = [NXData dataWithBytes:bytes length:length];
  }
  [stream close];
  return data;
}

// Reads an object back from bytes, with limits, and whether that failed
static id unbinary(Class cls, NXData *data, unsigned depth, size_t length, BOOL *failed) {
  NXStream *stream = [NXStream streamWithData:data];
  test_assert(stream != nil);
  NXArchive *archive = [NXArchive binaryDecoderWithStream:stream];
  if (depth > 0) {
    [archive setMaximumDepth:depth];
  }
  [archive setMaximumLength:length];
  id object = [archive decodeObjectOfClass:cls forKey:nil];
  *failed = [archive failed];
  test_assert(*failed == ([archive failure] != nil));
  [stream close];
  return object;
}

static id round_trip(Class cls, id object) {
  NXData *data = binary(object);
  test_assert(data != nil);
  BOOL failed;
  id read = unbinary(cls, data, 0, SIZE_MAX, &failed);
  test_assert(!failed);
  return read;
}

static void expect_bytes(id object, const uint8_t *bytes, size_t length) {
  NXData *data = binary(object);
  test_assert(data != nil && [data length] == length);
  test_assert(memcmp([data bytes], bytes, length) == 0);
}

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];

  // The bytes: a header, then the hash of the class and the values, little-endian
  {
    static const uint8_t string[] = {'P', 'F', 1, 0x4e, 0x8a, 0x3f, 0xd4, 2, 'h', 'i'};
    expect_bytes(@"hi", string, sizeof(string));
    static const uint8_t number[] = {'P', 'F', 1, 0xaa, 0xf3, 0x10, 0x90, 1,
                                     0xfe, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff};
    expect_bytes([NXNumber numberWithInt64:-2], number, sizeof(number));
    Point *p = [[[Point alloc] init] autorelease];
    p->x = 1;
    p->y = 0x01020304;
    static const uint8_t point[] = {'P', 'F', 1, 0x31, 0xef, 0xa8, 0xea,
                                    1, 0, 0, 0, 4, 3, 2, 1};
    expect_bytes(p, point, sizeof(point));
    static const uint8_t nothing[] = {'P', 'F', 1, 0, 0, 0, 0};
    expect_bytes(nil, nothing, sizeof(nothing));
  }

  // Every kind of value, exactly, with a subclass and a map with keys which aren't strings
  Everything *e = [[[Everything alloc] init] autorelease];
  e->b = YES;
  e->i32 = INT32_MIN;
  e->i64 = INT64_MIN;
  e->u32 = UINT32_MAX;
  e->u64 = UINT64_MAX;
  e->f32 = 0.1f;
  e->f64 = 1.0 / 3.0;
  e->string = [@"caf\xC3\xA9" retain];
  e->data = [[NXData dataWithBytes:"\x00\x01\x00\xff" length:4] retain];
  e->date = [[[NXDate dateWithSeconds:-5 nanoseconds:123456789] dateWithTimeZoneOffset:3600] retain];
  Point3 *p3 = [[[Point3 alloc] init] autorelease];
  p3->x = 7;
  p3->z = -9;
  e->point = [p3 retain];
  e->points = [[NXArray arrayWithObjects:p3, [NXNull nullValue], nil] retain];
  e->map = [[NXMap mapWithKeysAndObjects:[NXNumber numberWithInt32:1], @"one",
                                         @"list", [NXArray arrayWithObjects:@"a", nil], nil] retain];
  e->any = [[NXNumber numberWithFloat64:2.5] retain];

  Everything *back = round_trip([Everything class], e);
  test_assert(back != nil);
  test_assert(back->b && back->i32 == INT32_MIN && back->i64 == INT64_MIN);
  test_assert(back->u32 == UINT32_MAX && back->u64 == UINT64_MAX);
  test_assert(back->f32 == 0.1f && back->f64 == 1.0 / 3.0);
  test_assert([back->string isEqual:@"caf\xC3\xA9"] && [back->data isEqual:e->data]);
  test_assert([back->date isEqual:e->date] && [back->date timeZoneOffset] == 3600);
  test_assert(object_getClass(back->point) == [Point3 class]);
  test_assert(back->point->x == 7 && ((Point3 *)back->point)->z == -9);
  test_assert([back->points count] == 2);
  test_assert(object_getClass([back->points objectAtIndex:0]) == [Point3 class]);
  test_assert([back->points objectAtIndex:1] == [NXNull nullValue]);
  test_assert([[back->map objectForKey:[NXNumber numberWithInt32:1]] isEqual:@"one"]);
  test_assert([[[back->map objectForKey:@"list"] objectAtIndex:0] isEqual:@"a"]);
  test_assert([back->any float64Value] == 2.5 && back->none == nil);

  // Floating point numbers which JSON can't have
  NXNumber *n = round_trip(Nil, [NXNumber numberWithFloat64:1.0 / 0.0]);
  test_assert([n float64Value] == 1.0 / 0.0);

  // What can't be read
  BOOL failed;
  NXData *data = binary(e);
  test_assert(unbinary([Point class], data, 0, SIZE_MAX, &failed) == nil && failed);
  test_assert(unbinary([NXString class], data, 0, SIZE_MAX, &failed) == nil && failed);
  NXData *truncated = [NXData dataWithBytes:[data bytes] length:[data length] - 1];
  test_assert(unbinary([Everything class], truncated, 0, SIZE_MAX, &failed) == nil && failed);
  test_assert(unbinary(Nil, [NXData dataWithBytes:"JSON" length:4], 0, SIZE_MAX, &failed) == nil &&
              failed);
  test_assert(unbinary(Nil, [NXData dataWithBytes:"PF\x01\x01\x02\x03\x04" length:7], 0,
                       SIZE_MAX, &failed) == nil && failed);
  test_assert(unbinary(Nil, [NXData data], 0, SIZE_MAX, &failed) == nil && failed);

  // Limits on depth and length, checked before anything is allocated
  test_assert(unbinary([Everything class], data, 1, SIZE_MAX, &failed) == nil && failed);
  test_assert(unbinary([Everything class], data, 0, 3, &failed) == nil && failed);
  test_assert(unbinary([Everything class], data, 3, 5, &failed) != nil && !failed);
  static const uint8_t huge[] = {'P', 'F', 1, 0x4e, 0x8a, 0x3f, 0xd4,
                                 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f};
  test_assert(unbinary(Nil, [NXData dataWithBytes:huge length:sizeof(huge)], 0, 1000, &failed) ==
                  nil && failed);

  // A decoder can't encode, an encoder can't decode, and only one value at the top
  NXStream *stream = [NXStream streamWithCapacity:64];
  NXArchive *archive = [NXArchive binaryEncoderWithStream:stream];
  test_assert([archive format] == NXArchiveFormatBinary && [archive isEncoding]);
  test_assert([archive encodeInt32:1 forKey:nil]);
  test_assert(![archive encodeInt32:2 forKey:nil] && [archive failed]);
  [stream close];

  [pool release];
}
