#include <Foundation/Foundation.h>
#include <test/test.h>

static void check(NXMutableString *string, const char *expected) {
  test_assert_strequal([string cStr], expected);
  test_assert([string length] == strlen(expected));
  test_assert([string capacity] >= [string length]);
}

static void strings(NXZone *zone) {
  // It starts empty, or with the contents of another
  NXMutableString *string = [NXMutableString string];
  check(string, "");
  test_assert([string zone] == zone && [string capacity] == 0);
  test_assert([string isKindOfClass:[NXMutableString class]]);
  check([NXMutableString stringWithString:@"abc"], "abc");
  check([NXMutableString stringWithCString:"abc"], "abc");
  check([NXMutableString stringWithFormat:@"%d%@", 1, @"b"], "1b");
  check([NXMutableString stringWithCapacity:0], "");

  // Appending
  test_assert([string appendString:@"one"]);
  test_assert([string appendCString:" two"]);
  test_assert([string appendFormat:@" %s %@", "three", @"four"]);
  check(string, "one two three four");
  test_assert([string appendString:nil] && [string appendCString:NULL]);
  test_assert([string appendString:@""] && [string appendFormat:nil]);
  test_assert([string appendFormat:@""]);
  check(string, "one two three four");
  test_assert([string isEqual:@"one two three four"]);
  test_assert([@"one two three four" isEqual:string]);

  // A copy isn't changed
  NXString *copy = [NXString stringWithString:string];
  test_assert([string appendString:@"!"]);
  test_assert([copy isEqual:@"one two three four"] && ![copy isEqual:string]);
  test_assert(![copy isKindOfClass:[NXMutableString class]]);

  // It isn't moved until there's no room
  string = [NXMutableString stringWithCapacity:100];
  test_assert([string length] == 0 && [string capacity] == 100);
  const char *data = [string cStr];
  for (int i = 0; i < 10; i++) {
    test_assert([string appendString:@"0123456789"]);
  }
  test_assert([string cStr] == data && [string capacity] == 100);
  test_assert([string appendCString:"x"]);
  test_assert([string length] == 101 && [string capacity] >= 200);

  // To itself, with and without room
  for (int size = 1; size < 40; size++) {
    string = [NXMutableString string];
    char expected[81] = "";
    for (int i = 0; i < size; i++) {
      test_assert([string appendFormat:@"%c", 'a' + i % 26]);
      expected[i] = expected[size + i] = 'a' + i % 26;
    }
    NXMutableString *other = [NXMutableString stringWithString:string];
    NXMutableString *third = [NXMutableString stringWithCapacity:100];
    test_assert([third appendString:string]);
    test_assert([string appendString:string]);
    check(string, expected);
    test_assert([other appendCString:[other cStr]]);
    check(other, expected);
    test_assert([third appendFormat:@"%@", third]);
    check(third, expected);
  }

  // Trimming
  static const struct {
    const char *before, *after;
  } trims[] = {
      {"", ""},           {"   ", ""},       {"a", "a"},
      {" a", "a"},        {"a ", "a"},       {" \t\r\na b\n ", "a b"},
      {"\xC2\xA0", "\xC2\xA0"},
  };
  for (size_t i = 0; i < sizeof(trims) / sizeof(trims[0]); i++) {
    string = [NXMutableString stringWithCString:trims[i].before];
    [string trimWhitespace];
    check(string, trims[i].after);
    test_assert([string appendCString:"z"]);
    test_assert([string cStr][strlen(trims[i].after)] == 'z');
  }

  // Many
  string = [NXMutableString string];
  for (int i = 0; i < 1000; i++) {
    test_assert([string appendFormat:@"%d,", i % 10]);
  }
  test_assert([string length] == 2000 && [string cStr][1998] == '9');
}

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  strings(nil);
  [pool release];

  NXZone *zone = [NXZone zoneWithSize:8192];
  pool = [[NXAutoreleasePool alloc] init];
  strings(zone);
  [pool release];
  test_assert([zone count] == 0);
  [zone release];
}
