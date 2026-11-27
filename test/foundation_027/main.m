#include <Foundation/Foundation.h>
#include <string.h>
#include <test/test.h>

// The vectors of RFC 4648, section 10
static const struct {
  const char *bytes, *base64;
} vectors[] = {
    {"", ""},         {"f", "Zg=="},        {"fo", "Zm8="},
    {"foo", "Zm9v"},  {"foob", "Zm9vYg=="}, {"fooba", "Zm9vYmE="},
    {"foobar", "Zm9vYmFy"},
};

static void datas(NXZone *zone) {
  // Empty
  NXData *data = [NXData data];
  test_assert(data != nil && [data zone] == zone);
  test_assert([data length] == 0 && [data bytes] == NULL && [data capacity] == 0);
  test_assert_strequal([[data description] cStr], "<>");
  test_assert([[data base64String] isEqual:@""]);

  // Bytes, including zero, which are copied
  uint8_t bytes[] = {0x00, 0x0a, 0xff, 0x00, 0x7f};
  data = [NXData dataWithBytes:bytes length:sizeof(bytes)];
  bytes[0] = 0x55;
  test_assert([data length] == 5 && ((const uint8_t *)[data bytes])[0] == 0x00);
  test_assert_strequal([[data description] cStr], "<000aff007f>");
  test_assert([NXData dataWithBytes:NULL length:1] == nil);
  test_assert([[NXData dataWithBytes:NULL length:0] length] == 0);

  // Adding, which makes room, including from itself
  data = [NXData data];
  for (int i = 0; i < 100; i++) {
    uint8_t byte = (uint8_t)i;
    test_assert([data appendBytes:&byte length:1]);
  }
  test_assert([data length] == 100 && [data capacity] >= 100);
  test_assert([data appendBytes:"" length:0] && ![data appendBytes:NULL length:1]);
  test_assert([data appendData:data] && [data length] == 200);
  for (int i = 0; i < 200; i++) {
    test_assert(((const uint8_t *)[data bytes])[i] == (uint8_t)(i % 100));
  }
  test_assert([data appendBytes:(const uint8_t *)[data bytes] + 150 length:50]);
  test_assert([data length] == 250 && ((const uint8_t *)[data bytes])[249] == 99);
  test_assert([data appendData:nil] && [data length] == 250);
  test_assert([[NXData dataWithCapacity:64] capacity] == 64);
  test_assert([NXData dataWithCapacity:SIZE_MAX] == nil);

  // Base64 both ways
  for (size_t i = 0; i < sizeof(vectors) / sizeof(vectors[0]); i++) {
    size_t length = strlen(vectors[i].bytes);
    NXData *data = [NXData dataWithBytes:vectors[i].bytes length:length];
    NXString *base64 = [data base64String];
    test_assert_strequal([base64 cStr], vectors[i].base64);
    NXData *decoded = [NXData dataWithBase64String:base64];
    test_assert([decoded isEqual:data] && [decoded zone] == zone);
  }
  test_assert([[NXData dataWithBase64String:@"Zm8"] isEqual:
                  [NXData dataWithBytes:"fo" length:2]]);
  uint8_t all[256];
  for (int i = 0; i < 256; i++) {
    all[i] = (uint8_t)i;
  }
  data = [NXData dataWithBytes:all length:sizeof(all)];
  test_assert([[data base64String] hasSuffix:@"+fr7/P3+/w=="]);
  test_assert([[NXData dataWithBase64String:[data base64String]] isEqual:data]);
  const char *invalid[] = {"Z", "Zg=", "Zh==", "Zm 9v", "Zm9v\n", "Zm9-"};
  for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
    test_assert([NXData dataWithBase64String:[NXString stringWithCString:invalid[i]]] ==
                nil);
  }
  test_assert([NXData dataWithBase64String:@"Zm9v\0Zm9v"] == nil);
  test_assert([[NXData dataWithBase64String:nil] length] == 0);

  // Hashes
  data = [NXData dataWithBytes:"abc" length:3];
  test_assert_strequal(
      [[[data hashWithAlgorithm:NXHashAlgorithmSHA256] description] cStr],
      "<ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad>");
  test_assert_strequal([[[data hashWithAlgorithm:NXHashAlgorithmMD5] description] cStr],
                       "<900150983cd24fb0d6963f7d28e17f72>");
  test_assert([[[NXData data] hashWithAlgorithm:NXHashAlgorithmMD5] length] == 16);
  test_assert([data hashWithAlgorithm:(NXHashAlgorithm)99] == nil);

  // Equal, hashes and copies
  NXData *same = [NXData dataWithBase64String:@"YWJj"];
  test_assert([data isEqual:same] && [data hash] == [same hash]);
  test_assert(![data isEqual:[NXData dataWithBytes:"abd" length:3]]);
  test_assert(![data isEqual:@"abc"] && ![data isEqual:nil]);
  test_assert([[NXData data] isEqual:[NXData data]]);
  NXData *copy = [data copy];
  test_assert(copy != data && [copy isEqual:data] && [copy zone] == zone);
  test_assert([data appendBytes:"d" length:1] && [copy length] == 3);
  [copy release];

  // A stream of a copy of the bytes
  NXStream *stream = [NXStream streamWithData:data];
  test_assert([[stream readStringWithLength:10] isEqual:@"abcd"]);
  [stream close];
  stream = [NXStream streamWithData:[NXData data]];
  test_assert(stream != nil && [stream peek] == NXStreamEnd);
  [stream close];
}

test_main(0) {
  for (int i = 0; i < 3; i++) {
    NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
    datas(nil);
    [pool release];
  }

  NXZone *zone = [NXZone zoneWithSize:4096];
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  datas(zone);
  [pool release];
  test_assert([zone count] == 0);
  [zone release];
}
