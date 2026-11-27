// Archiving objects as JSON
#include <Foundation/Foundation.h>
#include <test/test.h>

///////////////////////////////////////////////////////////////////////////////
// Classes which are archived

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

@interface Config : NXObject <NXArchiving> {
@public
  NXString *name;
  BOOL enabled;
  double ratio;
  uint64_t big;
  Point *origin;
  NXArray *points;
  NXMap *labels;
  NXData *key;
  NXDate *when;
}
@end

@implementation Config
- (void)dealloc {
  [name release];
  [origin release];
  [points release];
  [labels release];
  [key release];
  [when release];
  [super dealloc];
}
- (BOOL)encodeWithArchive:(NXArchive *)archive {
  return [archive encodeObject:name forKey:@"name"] &&
         [archive encodeBool:enabled forKey:@"enabled"] &&
         [archive encodeFloat64:ratio forKey:@"ratio"] &&
         [archive encodeUnsignedInt64:big forKey:@"big"] &&
         [archive encodeObject:origin asClass:[Point class] forKey:@"origin"] &&
         [archive encodeObject:points forKey:@"points"] &&
         [archive encodeObject:labels forKey:@"labels"] &&
         [archive encodeObject:key forKey:@"key"] && [archive encodeObject:when forKey:@"when"];
}
- (id)initWithArchive:(NXArchive *)archive {
  self = [super init];
  name = [[archive decodeObjectOfClass:[NXString class] forKey:@"name"] retain];
  enabled = [archive decodeBoolForKey:@"enabled"];
  ratio = [archive decodeFloat64ForKey:@"ratio"];
  big = [archive decodeUnsignedInt64ForKey:@"big"];
  origin = [[archive decodeObjectOfClass:[Point class] forKey:@"origin"] retain];
  points = [[archive decodeArrayOfClass:[Point class] forKey:@"points"] retain];
  labels = [[archive decodeMapOfClass:[NXString class] forKey:@"labels"] retain];
  key = [[archive decodeObjectOfClass:[NXData class] forKey:@"key"] retain];
  when = [[archive decodeObjectOfClass:[NXDate class] forKey:@"when"] retain];
  if ([archive failed]) {
    [self release];
    return nil;
  }
  return self;
}
@end

// A class which can't be archived
@interface Opaque : NXObject
@end
@implementation Opaque
@end

///////////////////////////////////////////////////////////////////////////////
// Helpers

// Returns what an object is written as, or nil if it couldn't be
static NXString *json(id object, unsigned indent) {
  NXStream *stream = [NXStream streamWithCapacity:1024];
  NXArchive *archive = [NXArchive JSONEncoderWithStream:stream indent:indent];
  if (![archive encodeObject:object forKey:nil]) {
    test_assert([archive failed] && [archive failure] != nil);
    [stream close];
    return nil;
  }
  test_assert(![archive failed]);
  size_t length = [stream position];
  test_assert([stream seek:0 relative:NO]);
  NXString *string = [stream readStringWithLength:length];
  [stream close]; // there can only be so many open
  return string;
}

static void expect_json(id object, const char *expected) {
  NXString *string = json(object, 0);
  test_assert(string != nil);
  test_assert_strequal([string cStr], expected);
}

static NXStream *stream_of(const char *cStr) {
  NXStream *stream = [NXStream streamWithString:[NXString stringWithCString:cStr]];
  test_assert(stream != nil);
  return stream;
}

static id decode(Class cls, const char *cStr) {
  NXStream *stream = stream_of(cStr);
  id object = [NXArchive decodeObjectOfClass:cls fromStream:stream format:NXArchiveFormatJSON];
  [stream close];
  return object;
}

// Decodes JSON which has to fail
static void expect_failure(Class cls, const char *cStr) {
  NXStream *stream = stream_of(cStr);
  NXArchive *archive = [NXArchive JSONDecoderWithStream:stream];
  id object = [archive decodeObjectOfClass:cls forKey:nil];
  test_assert(object == nil && [archive failed] && [archive failure] != nil);
  [stream close];
}

static id round_trip(Class cls, id object) {
  NXString *string = json(object, 0);
  test_assert(string != nil);
  return decode(cls, [string cStr]);
}

///////////////////////////////////////////////////////////////////////////////
// Tests

static void encoding(void) {
  // JSON's own types
  expect_json(nil, "null");
  expect_json([NXNull nullValue], "null");
  expect_json([NXNumber trueValue], "true");
  expect_json([NXNumber falseValue], "false");
  expect_json([NXNumber numberWithInt64:INT64_MIN], "-9223372036854775808");
  expect_json([NXNumber numberWithUnsignedInt64:UINT64_MAX], "18446744073709551615");
  expect_json([NXNumber zeroValue], "0");
  expect_json(@"caf\xC3\xA9", "\"caf\xC3\xA9\"");
  expect_json(@"a\"b\\c\n\t", "\"a\\\"b\\\\c\\n\\t\"");
  expect_json([NXString stringWithCString:"\x01\x1f"], "\"\\u0001\\u001f\"");
  expect_json([NXArray array], "[]");
  expect_json([NXMap map], "{}");
  expect_json([NXArray arrayWithObjects:@"a", [NXNumber numberWithInt32:1], [NXNull nullValue], nil],
              "[\"a\",1,null]");
  expect_json([NXMap mapWithKeysAndObjects:@"b", [NXNumber numberWithInt32:2], @"a",
                                           [NXArray arrayWithObjects:@"x", nil], nil],
              "{\"a\":[\"x\"],\"b\":2}");
  expect_json([NXData dataWithBytes:"\x00\x01\xff" length:3], "\"AAH/\"");
  expect_json([NXDate dateWithSeconds:0 nanoseconds:0], "\"1970-01-01T00:00:00Z\"");

  // Floats, with as few digits as read back the same
  expect_json([NXNumber numberWithFloat64:0.1], "0.1");
  expect_json([NXNumber numberWithFloat64:-2.5], "-2.5");
  expect_json([NXNumber numberWithFloat64:1e300], "1e+300");
  expect_json([NXNumber numberWithFloat32:0.5f], "0.5");
  // picofuse writes 9 significant digits at most, so a double reads back to that
  double third = 1.0 / 3.0;
  NXNumber *read = round_trip(Nil, [NXNumber numberWithFloat64:third]);
  double error = [read float64Value] - third;
  test_assert(read != nil && error < 1e-9 && error > -1e-9);
  float tenth = 0.1f;
  read = round_trip(Nil, [NXNumber numberWithFloat32:tenth]);
  test_assert(read != nil && (float)[read float64Value] == tenth);

  // Indented
  NXString *indented =
      json([NXMap mapWithKeysAndObjects:@"a", [NXArray arrayWithObjects:@"x", @"y", nil], @"b",
                                        [NXMap map], nil],
           2);
  test_assert_strequal([indented cStr], "{\n  \"a\": [\n    \"x\",\n    \"y\"\n  ],\n  \"b\": {}\n}\n");

  // What can't be written
  test_assert(json([NXNumber numberWithFloat64:0.0 / 0.0], 0) == nil);
  test_assert(json([NXNumber numberWithFloat64:1.0 / 0.0], 0) == nil);
  test_assert(json([NXMap mapWithKeysAndObjects:@"a", @"b", [NXNumber numberWithInt32:1], @"c", nil],
                   0) == nil);
  test_assert(json([[[Opaque alloc] init] autorelease], 0) == nil);

  // Only one value at the top, and objects need keys
  NXStream *stream = [NXStream streamWithCapacity:64];
  NXArchive *archive = [NXArchive JSONEncoderWithStream:stream indent:0];
  test_assert([archive encodeInt32:1 forKey:nil]);
  test_assert(![archive encodeInt32:2 forKey:nil] && [archive failed]);
  test_assert(![archive encodeInt32:3 forKey:nil]); // it stays failed
}

static void objects(void) {
  Point *p = [[[Point alloc] init] autorelease];
  p->x = 1;
  p->y = -2;
  expect_json(p, "{\"x\":1,\"y\":-2}");
  Point *q = round_trip([Point class], p);
  test_assert(q != nil && q->x == 1 && q->y == -2);

  // A subclass is named only where something else is expected
  Point3 *p3 = [[[Point3 alloc] init] autorelease];
  p3->x = 4;
  p3->z = 6;
  expect_json(p3, "{\"x\":4,\"y\":0,\"z\":6}");

  Config *config = [[[Config alloc] init] autorelease];
  config->name = [@"main" retain];
  config->enabled = YES;
  config->ratio = 0.25;
  config->big = UINT64_MAX;
  config->origin = [p3 retain];
  config->points = [[NXArray arrayWithObjects:p, p, nil] retain];
  config->labels = [[NXMap mapWithKeysAndObjects:@"k", @"v", nil] retain];
  config->key = [[NXData dataWithBytes:"key" length:3] retain];
  config->when = [[NXDate dateWithSeconds:1788694625 nanoseconds:0] retain];
  expect_json(config,
              "{\"name\":\"main\",\"enabled\":true,\"ratio\":0.25,\"big\":18446744073709551615,"
              "\"origin\":{\"@class\":\"Point3\",\"x\":4,\"y\":0,\"z\":6},"
              "\"points\":[{\"x\":1,\"y\":-2},{\"x\":1,\"y\":-2}],\"labels\":{\"k\":\"v\"},"
              "\"key\":\"a2V5\",\"when\":\"2026-09-06T11:37:05Z\"}");

  Config *back = round_trip([Config class], config);
  test_assert(back != nil);
  test_assert([back->name isEqual:@"main"] && back->enabled && back->ratio == 0.25);
  test_assert(back->big == UINT64_MAX);
  test_assert(object_getClass(back->origin) == [Point3 class]);
  test_assert(((Point3 *)back->origin)->z == 6 && back->origin->x == 4);
  test_assert([back->points count] == 2 && ((Point *)[back->points objectAtIndex:1])->y == -2);
  test_assert([[back->labels objectForKey:@"k"] isEqual:@"v"]);
  test_assert([back->key isEqual:config->key] && [back->when isEqual:config->when]);

  // Missing keys and nulls are zero or nil
  Config *empty = decode([Config class], "{\"name\":null}");
  test_assert(empty != nil && empty->name == nil && !empty->enabled && empty->ratio == 0);
  test_assert(empty->origin == nil && empty->points == nil);
}

static void decoding(void) {
  // Whatever is there
  NXMap *map = decode(Nil, " { \"a\" : [1, -2.5, \"x\", true, null, {}], \"b\": \"\\u00e9\\n\" } ");
  test_assert(map != nil && [map count] == 2);
  NXArray *a = [map objectForKey:@"a"];
  test_assert([a count] == 6);
  test_assert([[a objectAtIndex:0] int64Value] == 1);
  test_assert([[a objectAtIndex:1] float64Value] == -2.5);
  test_assert([[a objectAtIndex:3] boolValue]);
  test_assert([a objectAtIndex:4] == [NXNull nullValue]);
  test_assert_strequal([[map objectForKey:@"b"] cStr], "\xC3\xA9\n");
  test_assert([decode(Nil, "18446744073709551615") unsignedInt64Value] == UINT64_MAX);
  test_assert([decode(Nil, "1e2") float64Value] == 100);

  // Of the wrong type, out of range, or not a subclass
  expect_failure([NXString class], "1");
  expect_failure([Point class], "[]");
  expect_failure([Point class], "{\"x\":\"1\"}");
  expect_failure([Point class], "{\"x\":1.5}");
  expect_failure([Point class], "{\"x\":true}");
  expect_failure([Point class], "{\"x\":2147483648}");
  expect_failure([Point class], "{\"@class\":\"Config\"}");
  expect_failure([Point class], "{\"@class\":\"Nothing\"}");
  expect_failure([Point class], "{\"@class\":\"Opaque\"}");
  expect_failure([NXData class], "\"not base64!\"");
  expect_failure([NXDate class], "\"yesterday\"");
  expect_failure([Opaque class], "{}");
  Point *p = decode([Point class], "{\"x\":2147483647,\"y\":-2147483648,\"other\":1}");
  test_assert(p != nil && p->x == INT32_MAX && p->y == INT32_MIN);
  p = decode([Point class], "{\"x\":3.0}");
  test_assert(p != nil && p->x == 3);

  // JSON which isn't valid
  static const char *invalid[] = {
      "", "   ", "[1,]", "[1 2]", "{\"a\" 1}", "{\"a\":1,}", "{1:2}", "[", "{\"a\":",
      "01", "+1", "1.", ".5", "1e", "-", "nul", "True", "'a'", "\"a", "[1]]", "1 2",
      "\"\\x\"", "NaN", "1e400",
  };
  for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
    expect_failure(Nil, invalid[i]);
  }

  // Limits on depth and length
  NXArchive *archive = [NXArchive
      JSONDecoderWithStream:[NXStream streamWithString:@"[[[[1]]]]"]];
  [archive setMaximumDepth:3];
  test_assert([archive decodeObjectOfClass:Nil forKey:nil] == nil && [archive failed]);
  archive = [NXArchive JSONDecoderWithStream:[NXStream streamWithString:@"[[[1]]]"]];
  [archive setMaximumDepth:3];
  test_assert([archive decodeObjectOfClass:Nil forKey:nil] != nil && ![archive failed]);
  archive = [NXArchive JSONDecoderWithStream:[NXStream streamWithString:@"[\"abcd\"]"]];
  [archive setMaximumLength:3];
  test_assert([archive decodeObjectOfClass:Nil forKey:nil] == nil && [archive failed]);
  archive = [NXArchive JSONDecoderWithStream:[NXStream streamWithString:@"[1,2,3,4]"]];
  [archive setMaximumLength:3];
  test_assert([archive decodeObjectOfClass:Nil forKey:nil] == nil && [archive failed]);

  // Keys at the top of a decoder
  archive = [NXArchive JSONDecoderWithStream:[NXStream streamWithString:@"{\"n\":7}"]];
  test_assert([archive containsKey:@"n"] && ![archive containsKey:@"m"]);
  test_assert([archive decodeInt64ForKey:@"n"] == 7 && [archive decodeInt64ForKey:@"m"] == 0);
  test_assert(![archive failed] && ![archive isEncoding]);
  test_assert(![archive encodeInt32:1 forKey:@"n"] && [archive failed]);
}

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  encoding();
  objects();
  decoding();
  [pool release];
}
