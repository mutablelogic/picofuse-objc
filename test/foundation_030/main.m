// NXArray subarrays, joining and sorting, and comparing numbers
#include <Foundation/Foundation.h>
#include <test/test.h>

// An object with a key to sort by, and the order it was made in
@interface Item : NXObject {
@public
  int key;
  int order;
}
@end

@implementation Item
- (NXComparisonResult)compare:(Item *)other {
  return key < other->key   ? NXComparisonAscending
         : key > other->key ? NXComparisonDescending
                            : NXComparisonSame;
}
@end

static NXNumber *num(int64_t value) {
  return [NXNumber numberWithInt64:value];
}

static void subarrays(void) {
  NXArray *array = [NXArray arrayWithObjects:@"a", @"b", @"c", @"d", @"e", nil];
  NXArray *sub = [array subarrayFromIndex:1 count:3];
  test_assert([sub count] == 3);
  test_assert([sub objectAtIndex:0] == [array objectAtIndex:1]);
  test_assert([sub objectAtIndex:2] == [array objectAtIndex:3]);
  test_assert([[array subarrayFromIndex:0 count:5] isEqual:array]);
  test_assert([[array subarrayFromIndex:0 count:0] count] == 0);
  test_assert([[array subarrayFromIndex:5 count:0] count] == 0);
  test_assert([array subarrayFromIndex:5 count:1] == nil);
  test_assert([array subarrayFromIndex:6 count:0] == nil);
  test_assert([array subarrayFromIndex:4 count:2] == nil);
  test_assert([array subarrayFromIndex:1 count:SIZE_MAX] == nil);
  test_assert([[NXArray array] subarrayFromIndex:0 count:0] != nil);
}

static void joining(void) {
  test_assert_strequal([[[NXArray array] componentsJoinedByString:@", "] cStr], "");
  NXArray *array = [NXArray arrayWithObjects:@"a", nil];
  test_assert_strequal([[array componentsJoinedByString:@", "] cStr], "a");
  array = [NXArray arrayWithObjects:@"a", @"b", @"c", nil];
  test_assert_strequal([[array componentsJoinedByString:@", "] cStr], "a, b, c");
  test_assert_strequal([[array componentsJoinedByString:nil] cStr], "abc");
  test_assert_strequal([[array componentsJoinedByString:@""] cStr], "abc");

  // Other objects by their description
  array = [NXArray arrayWithObjects:num(1), @"x", num(-2), nil];
  test_assert_strequal([[array componentsJoinedByString:@"/"] cStr], "1/x/-2");
}

// Checks numbers are in order
static void expect_sorted(NXArray *array) {
  for (size_t i = 1; i < [array count]; i++) {
    test_assert([[array objectAtIndex:i - 1] compare:[array objectAtIndex:i]] !=
                NXComparisonDescending);
  }
}

static void sorting(void) {
  NXArray *array = [NXArray array];
  test_assert([array sortUsingSelector:@selector(compare:)]);
  test_assert(![array sortUsingSelector:NULL]);

  // Sizes either side of where inserting stops, and of halves, in several orders
  static const size_t sizes[] = {1, 2, 3, 8, 9, 16, 17, 100, 257};
  uint32_t seed = 1;
  for (size_t s = 0; s < sizeof(sizes) / sizeof(sizes[0]); s++) {
    size_t n = sizes[s];
    for (int kind = 0; kind < 4; kind++) {
      [array removeAllObjects];
      int64_t sum = 0;
      for (size_t i = 0; i < n; i++) {
        int64_t value;
        switch (kind) {
        case 0: value = (int64_t)i; break;     // already in order
        case 1: value = (int64_t)(n - i); break; // reversed
        case 2: value = 7; break;                // all the same
        default:
          seed = seed * 1103515245u + 12345u;
          value = (int64_t)(seed >> 16) % 50 - 25; // with many the same
        }
        sum += value;
        test_assert([array appendObject:num(value)]);
      }
      test_assert([array sortUsingSelector:@selector(compare:)]);
      test_assert([array count] == n);
      expect_sorted(array);
      for (NXNumber *number in array) {
        sum -= [number int64Value];
      }
      test_assert(sum == 0);
    }
  }

  // Those which are the same keep their order
  [array removeAllObjects];
  for (int i = 0; i < 100; i++) {
    Item *item = [[Item alloc] init];
    seed = seed * 1103515245u + 12345u;
    item->key = (int)((seed >> 16) % 5);
    item->order = i;
    test_assert([array appendObject:item]);
    [item release];
  }
  test_assert([array sortUsingSelector:@selector(compare:)]);
  for (size_t i = 1; i < [array count]; i++) {
    Item *a = [array objectAtIndex:i - 1], *b = [array objectAtIndex:i];
    test_assert(a->key < b->key || (a->key == b->key && a->order < b->order));
  }

  // Strings, and numbers of different kinds
  array = [NXArray arrayWithObjects:@"pear", @"apple", @"fig", @"banana", nil];
  test_assert([array sortUsingSelector:@selector(compare:)]);
  test_assert_strequal([[array componentsJoinedByString:@" "] cStr],
                       "apple banana fig pear");
  array = [NXArray arrayWithObjects:[NXNumber numberWithFloat64:2.5], num(-3),
                                    [NXNumber numberWithUnsignedInt64:UINT64_MAX],
                                    [NXNumber numberWithFloat32:-0.5f], num(2),
                                    [NXNumber numberWithFloat64:0.0 / 0.0],
                                    [NXNumber zeroValue], nil];
  test_assert([array sortUsingSelector:@selector(compare:)]);
  test_assert_strequal([[[array subarrayFromIndex:0 count:5] componentsJoinedByString:@" "] cStr],
                       "-3 -0.5 0 2 2.5");
  test_assert([[array objectAtIndex:5] unsignedInt64Value] == UINT64_MAX);
}

static void expect_compare(NXNumber *a, NXNumber *b, NXComparisonResult result) {
  test_assert([a compare:b] == result);
  test_assert([b compare:a] == (NXComparisonResult)-result);
}

static void comparing(void) {
  NXNumber *f53 = [NXNumber numberWithFloat64:9007199254740992.0]; // 2^53
  NXNumber *nan = [NXNumber numberWithFloat64:0.0 / 0.0];
  NXNumber *inf = [NXNumber numberWithFloat64:1.0 / 0.0];

  // Integers of every kind, by sign and size
  expect_compare(num(1), num(2), NXComparisonAscending);
  expect_compare(num(-2), num(-1), NXComparisonAscending);
  expect_compare(num(-1), [NXNumber numberWithUnsignedInt64:UINT64_MAX], NXComparisonAscending);
  expect_compare(num(INT64_MIN), num(INT64_MAX), NXComparisonAscending);
  expect_compare([NXNumber numberWithInt16:5], [NXNumber numberWithUnsignedInt32:5],
                 NXComparisonSame);
  expect_compare([NXNumber zeroValue], num(0), NXComparisonSame);
  expect_compare([NXNumber trueValue], num(1), NXComparisonSame);
  expect_compare([NXNumber falseValue], [NXNumber trueValue], NXComparisonAscending);

  // Floats and integers, exactly
  expect_compare([NXNumber numberWithFloat64:1.0], num(1), NXComparisonSame);
  expect_compare([NXNumber numberWithFloat64:-0.0], num(0), NXComparisonSame);
  expect_compare([NXNumber numberWithFloat64:0.5], num(0), NXComparisonDescending);
  expect_compare([NXNumber numberWithFloat64:-0.5], num(0), NXComparisonAscending);
  expect_compare([NXNumber numberWithFloat64:-1.5], num(-1), NXComparisonAscending);
  expect_compare([NXNumber numberWithFloat64:-1.5], num(-2), NXComparisonDescending);
  expect_compare(f53, num(9007199254740993LL), NXComparisonAscending);
  expect_compare(f53, num(9007199254740992LL), NXComparisonSame);
  expect_compare([NXNumber numberWithFloat64:1e30],
                 [NXNumber numberWithUnsignedInt64:UINT64_MAX], NXComparisonDescending);
  expect_compare([NXNumber numberWithFloat64:-1e30], num(INT64_MIN), NXComparisonAscending);
  expect_compare(inf, [NXNumber numberWithUnsignedInt64:UINT64_MAX], NXComparisonDescending);

  // Two floats
  expect_compare([NXNumber numberWithFloat32:1.5f], [NXNumber numberWithFloat64:1.5],
                 NXComparisonSame);
  expect_compare([NXNumber numberWithFloat64:-0.0], [NXNumber numberWithFloat64:0.0],
                 NXComparisonSame);
  expect_compare([NXNumber numberWithFloat64:1.0], inf, NXComparisonAscending);

  // Not a number is after every number, and the same as itself
  expect_compare(nan, inf, NXComparisonDescending);
  expect_compare(nan, num(INT64_MAX), NXComparisonDescending);
  expect_compare(nan, [NXNumber numberWithFloat64:0.0 / 0.0], NXComparisonSame);

  // nil is zero
  test_assert([num(0) compare:nil] == NXComparisonSame);
  test_assert([num(-1) compare:nil] == NXComparisonAscending);
  test_assert([[NXNumber numberWithFloat64:0.25] compare:nil] == NXComparisonDescending);
}

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  subarrays();
  joining();
  sorting();
  comparing();
  [pool release];

  // Sorting in a zone, which is where the room for it comes from
  NXZone *zone = [NXZone zoneWithSize:8192];
  pool = [[NXAutoreleasePool alloc] init];
  NXArray *array = [[NXArray allocWithZone:zone] initWithCapacity:64];
  for (int64_t i = 64; i > 0; i--) {
    test_assert([array appendObject:num(i)]);
  }
  test_assert([array sortUsingSelector:@selector(compare:)]);
  expect_sorted(array);
  [array release];
  [pool release];
  test_assert([zone count] == 0);
  [zone release];
}
