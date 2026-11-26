#include <Foundation/Foundation.h>
#include <test/test.h>

// Each kind of string
static NXString *kind(int i, const char *cStr) {
  return i == 0 ? [NXString stringWithCString:cStr]
                : [NXMutableString stringWithCString:cStr];
}

static void check_mutable(NXMutableString *string, const char *expected) {
  test_assert_strequal([string cStr], expected);
  test_assert([string length] == strlen(expected));

  // What's appended is in the right place
  test_assert([string appendCString:"|"]);
  test_assert([string length] == strlen(expected) + 1);
  test_assert([string cStr][strlen(expected)] == '|');
}

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  id none = nil;

  // Runes
  test_assert([@"" runeCount] == 0 && [@"abc" runeCount] == 3);
  test_assert([@"\xC3\xA9t\xC3\xA9" runeCount] == 3);
  test_assert([@"\xC3\xA9t\xC3\xA9" length] == 5);
  test_assert([@"\xF0\x9F\x98\x80" runeCount] == 1);

  // Comparison, of every pair of these, which are in order
  static const char *ordered[] = {"",   "A",  "AB", "B",
                                  "a",  "aa", "ab", "b",
                                  "z",  "\xC3\xA9"};
  const int count = sizeof(ordered) / sizeof(ordered[0]);
  for (int i = 0; i < count; i++) {
    for (int j = 0; j < count; j++) {
      NXComparisonResult expected = i < j   ? NXComparisonAscending
                                    : i > j ? NXComparisonDescending
                                            : NXComparisonSame;
      for (int k = 0; k < 4; k++) {
        NXString *a = kind(k % 2, ordered[i]), *b = kind(k / 2, ordered[j]);
        test_assert([a compare:b] == expected);
        test_assert([a isEqual:b] == (expected == NXComparisonSame));
      }
    }
  }
  test_assert([@"abc" compare:[NXString stringWithCString:"abc"]] ==
              NXComparisonSame);
  test_assert([@"" compare:none] == NXComparisonSame);
  test_assert([@"a" compare:none] == NXComparisonDescending);

  // Prefixes, suffixes, and what's in a string
  for (int i = 0; i < 2; i++) {
    NXString *string = kind(i, "hello world");
    test_assert([string hasPrefix:@"hello"] && [string hasPrefix:@""]);
    test_assert([string hasPrefix:string] && [string hasPrefix:none]);
    test_assert(![string hasPrefix:@"world"] && ![string hasPrefix:@"Hello"]);
    test_assert(![string hasPrefix:@"hello world!"]);
    test_assert([string hasSuffix:@"world"] && [string hasSuffix:@""]);
    test_assert([string hasSuffix:string] && [string hasSuffix:none]);
    test_assert(![string hasSuffix:@"hello"]);
    test_assert(![string hasSuffix:@"!hello world"]);
    test_assert([string containsString:@"lo wo"] && [string containsString:@""]);
    test_assert([string containsString:string] && [string containsString:none]);
    test_assert(![string containsString:@"low"]);
    test_assert([string indexOfSubstring:@"o"] == 4);
    test_assert([string indexOfSubstring:@"world"] == 6);
    test_assert([string indexOfSubstring:@"hello"] == 0);
    test_assert([string indexOfSubstring:@""] == 0);
    test_assert([string indexOfSubstring:@"hello world!"] == NXNotFound);
    test_assert([@"" indexOfSubstring:string] == NXNotFound);
  }
  test_assert([@"constant" hasPrefix:@"con"] && [@"constant" hasSuffix:@"ant"]);
  test_assert([@"aab" indexOfSubstring:@"ab"] == 1);

  // Changing case, as far as Latin-1
  NXMutableString *string = [NXMutableString stringWithCString:"Hello 1\xC3\xA9"];
  [string toUppercase];
  check_mutable(string, "HELLO 1\xC3\x89");
  [string toLowercase];
  check_mutable(string, "hello 1\xC3\xA9|");
  string = [NXMutableString string];
  [string toUppercase];
  [string toLowercase];
  check_mutable(string, "");

  // Trimming
  string = [NXMutableString stringWithCString:"one two one"];
  test_assert(![string trimPrefix:@"two"] && ![string trimSuffix:@"two"]);
  test_assert(![string trimPrefix:@""] && ![string trimSuffix:none]);
  test_assert([string trimPrefix:@"one"]);
  test_assert_strequal([string cStr], " two one");
  test_assert([string trimSuffix:@"one"] && [string length] == 5);
  [string trimWhitespace];
  check_mutable(string, "two");
  test_assert([string trimSuffix:@"|"] && [string trimSuffix:string]);
  check_mutable(string, "");
  string = [NXMutableString stringWithCString:"self"];
  test_assert([string trimPrefix:string]);
  check_mutable(string, "");

  // A string which has never had anything in it
  string = [NXMutableString string];
  [string trimWhitespace];
  test_assert(![string trimPrefix:@"a"] && ![string trimSuffix:@"a"]);
  test_assert(![string trimPrefix:@""] && [string runeCount] == 0);
  check_mutable(string, "");

  [pool release];
}
