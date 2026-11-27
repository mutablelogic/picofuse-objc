// Splitting strings by a separator, and into words
#include <Foundation/Foundation.h>
#include <test/test.h>

// Checks the parts, joined with "|"
static void expect_parts(NXArray *parts, const char *joined) {
  test_assert(parts != nil);
  test_assert_strequal([[parts componentsJoinedByString:@"|"] cStr], joined);
}

static void expect_split(NXString *string, NXString *separator, size_t count,
                         const char *joined) {
  NXArray *parts = [string componentsSeparatedByString:separator];
  test_assert(parts != nil && [parts count] == count);
  expect_parts(parts, joined);

  // Joining them again gives the string back, when there's a separator
  if ([separator length] > 0) {
    test_assert([[parts componentsJoinedByString:separator] isEqual:string]);
  }
}

static void separators(void) {
  expect_split(@"a,b,c", @",", 3, "a|b|c");
  expect_split(@"a,,b", @",", 3, "a||b");
  expect_split(@",a,", @",", 3, "|a|");
  expect_split(@",", @",", 2, "|");
  expect_split(@"", @",", 1, "");
  expect_split(@"abc", @",", 1, "abc");

  // Longer separators, which don't overlap where they're found
  expect_split(@"a::b::c", @"::", 3, "a|b|c");
  expect_split(@"a:::b", @"::", 2, "a|:b");
  expect_split(@"::", @"::", 2, "|");
  expect_split(@"abc", @"abcd", 1, "abc");

  // UTF-8, as bytes
  expect_split(@"caf\xC3\xA9\xE2\x80\x94th\xC3\xA9", @"\xE2\x80\x94", 2,
               "caf\xC3\xA9|th\xC3\xA9");

  // No separator, or an empty one, is the string on its own
  NXArray *parts = [@"a,b" componentsSeparatedByString:nil];
  test_assert([parts count] == 1);
  expect_parts(parts, "a,b");
  parts = [@"a,b" componentsSeparatedByString:@""];
  test_assert([parts count] == 1);
  expect_parts(parts, "a,b");

  // The parts are new strings, from mutable ones too
  NXMutableString *mutable = [NXMutableString stringWithCString:"x y"];
  parts = [mutable componentsSeparatedByString:@" "];
  test_assert([mutable appendCString:"z"]);
  expect_parts(parts, "x|y");
}

static void words(void) {
  expect_parts([@"a b c" componentsSeparatedByWhitespace], "a|b|c");
  expect_parts([@"  a  b " componentsSeparatedByWhitespace], "a|b");
  expect_parts([@"\ta\r\nb\n" componentsSeparatedByWhitespace], "a|b");
  expect_parts([@"word" componentsSeparatedByWhitespace], "word");
  test_assert([[@"" componentsSeparatedByWhitespace] count] == 0);
  test_assert([[@" \t\n " componentsSeparatedByWhitespace] count] == 0);

  // Unicode's spaces, such as no-break, em and ideographic, but not zero width
  expect_parts([@"a\xC2\xA0" "b\xE2\x80\x83" "c\xE3\x80\x80" "d" componentsSeparatedByWhitespace],
               "a|b|c|d");
  expect_parts([@"a\xE2\x80\x8B" "b" componentsSeparatedByWhitespace], "a\xE2\x80\x8B" "b");
  expect_parts([@"caf\xC3\xA9 th\xC3\xA9" componentsSeparatedByWhitespace],
               "caf\xC3\xA9|th\xC3\xA9");
}

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  separators();
  words();
  [pool release];

  // In a zone, everything is released
  NXZone *zone = [NXZone zoneWithSize:8192];
  pool = [[NXAutoreleasePool alloc] init];
  NXString *string = [[NXString allocWithZone:zone] initWithCString:"one two,three"];
  test_assert([[string componentsSeparatedByString:@","] count] == 2);
  test_assert([[string componentsSeparatedByWhitespace] count] == 2);
  [string release];
  [pool release];
  test_assert([zone count] == 0);
  [zone release];
}
