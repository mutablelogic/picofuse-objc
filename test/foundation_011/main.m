#include <Foundation/Foundation.h>
#include <test/test.h>

// Takes any kind of string
static size_t length_of(NXString *string) { return [string length]; }

static void strings(void) {
  NXString *apple = @"apple";
  NXString *same = @"apple";
  NXString *longer = @"apples";
  NXString *other = @"grape";

  test_assert(length_of(apple) == 5 && length_of(longer) == 6);
  test_assert(length_of(@"") == 0 && length_of(nil) == 0);
  test_assert(length_of(@"\xC3\xA9") == 2);
  test_assert_strequal([apple cStr], "apple");
  test_assert_strequal([@"" cStr], "");

  // It's an NXObject, and a string
  test_assert([apple isKindOfClass:[NXConstantString class]]);
  test_assert([apple isKindOfClass:[NXString class]]);
  test_assert([apple isKindOfClass:[NXObject class]]);
  test_assert([apple zone] == nil);

  // It's equal to a string with the same contents
  test_assert([apple isEqual:apple] && [apple isEqual:same]);
  test_assert(![apple isEqual:longer] && ![longer isEqual:apple]);
  test_assert(![apple isEqual:other] && ![apple isEqual:nil]);
  test_assert([@"" isEqual:@""] && ![@"" isEqual:apple]);
  test_assert(![@"0" isEqual:[NXNumber zeroValue]]);
  test_assert(![[NXNumber zeroValue] isEqual:@"0"]);
  test_assert(![@"null" isEqual:[NXNull nullValue]]);

  // It isn't affected by being released
  for (int i = 0; i < 3; i++) {
    [apple release];
    test_assert([apple retain] == apple && [apple autorelease] == apple);
  }
  test_assert_strequal([apple cStr], "apple");
}

test_main(0) {
  test_assert([NXAutoreleasePool currentPool] == nil);
  strings();

  // Constant strings can be added to a pool, but autoreleasing one doesn't
  NXZone *zone = [NXZone zoneWithSize:1024];
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  strings();
  test_assert([pool count] == 0);
  [pool addObject:@"string"];
  test_assert([pool count] == 1);
  [pool release];
  test_assert([zone count] == 0);
  [zone release];
  strings();

  // Only the compiler makes them
  test_assert([NXConstantString alloc] == nil);
}
