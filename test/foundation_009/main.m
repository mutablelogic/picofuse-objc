#include <Foundation/Foundation.h>
#include <test/test.h>

static void null(void) {
  // There's only one, however it's obtained
  NXNull *value = [NXNull nullValue];
  test_assert(value != nil && value == [NXNull nullValue]);
  test_assert([[NXNull alloc] init] == value);
  test_assert([value class] == [NXNull class]);
  test_assert([value isKindOfClass:[NXObject class]]);
  test_assert([value zone] == nil);

  // It's only equal to itself
  test_assert([value isEqual:value]);
  test_assert(![value isEqual:nil]);
  test_assert(![value isEqual:[NXNumber zeroValue]]);
  test_assert(![value isEqual:[NXNumber falseValue]]);
  test_assert(![[NXNumber zeroValue] isEqual:value]);
  test_assert(![value isEqual:[NXNull class]]);

  // It's not affected by being released
  for (int i = 0; i < 3; i++) {
    [value release];
    test_assert([value retain] == value && [value autorelease] == value);
  }
  test_assert([NXNull nullValue] == value && [value isEqual:value]);
}

test_main(0) {
  // It doesn't need a pool
  test_assert([NXAutoreleasePool currentPool] == nil);
  null();
  NXNull *value = [NXNull nullValue];

  // It isn't added to one, or allocated in a zone, and it outlives both
  NXZone *zone = [NXZone zoneWithSize:1024];
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  size_t count = [zone count];
  null();
  test_assert([pool count] == 0 && [zone count] == count);
  [pool addObject:value];
  [pool release];
  test_assert([zone count] == 0);
  [zone release];
  null();
  test_assert([NXNull nullValue] == value);
}
