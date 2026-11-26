#include "../../src/Foundation/NXNumber+Private.h"
#include <Foundation/Foundation.h>
#include <math.h>
#include <test/test.h>

// Returns a number from a C string
static NXNumber *number(const char *cStr) {
  return [NXNumber numberWithString:[NXString stringWithCString:cStr]];
}

// Returns a string from a quoted C string
static NXString *unquote(const char *cStr) {
  return [NXString stringWithQuotedString:[NXString stringWithCString:cStr]];
}

static void numbers(void) {
  // Booleans
  test_assert(number("true") == [NXNumber trueValue]);
  test_assert(number("false") == [NXNumber falseValue]);

  // Signed integers
  NXNumber *n = number("42");
  test_assert(n != nil && ![n isFloat] && [n int64Value] == 42);
  test_assert([number("-7") int64Value] == -7 && [number("+7") int64Value] == 7);
  test_assert(number("0") == [NXNumber zeroValue]);
  test_assert([number("0x1F") int64Value] == 31);
  test_assert([number("0b101") int64Value] == 5);
  test_assert([number("0o17") int64Value] == 15);
  test_assert([number("017") int64Value] == 15);
  n = number("-9223372036854775808");
  test_assert(![n isFloat] && [n int64Value] == INT64_MIN);
  n = number("9223372036854775807");
  test_assert(![n isFloat] && [n int64Value] == INT64_MAX);

  // Unsigned, when they don't fit in an int64_t
  n = number("9223372036854775808");
  test_assert(![n isFloat] && [n unsignedInt64Value] == (uint64_t)INT64_MAX + 1);
  n = number("18446744073709551615");
  test_assert(![n isFloat] && [n unsignedInt64Value] == UINT64_MAX);
  n = number("0xFFFFFFFFFFFFFFFF");
  test_assert(![n isFloat] && [n unsignedInt64Value] == UINT64_MAX);

  // Floats, including integers which don't fit
  n = number("18446744073709551616");
  test_assert([n isFloat] && [n float64Value] == 18446744073709551616.0);
  n = number("-9223372036854775809");
  test_assert([n isFloat] && [n float64Value] <= -9223372036854775808.0 &&
              [n float64Value] > -9223372036854780000.0);
  n = number("3.14");
  test_assert([n isFloat] && [n float64Value] == 3.14);
  test_assert([number(".5") float64Value] == 0.5);
  test_assert([number("5.") float64Value] == 5.0);
  test_assert([number("1e10") float64Value] == 1e10);
  test_assert([number("-1.5e-3") float64Value] == -1.5e-3);
  test_assert(isinf([number("Inf") float64Value]));
  test_assert([number("-Inf") float64Value] < 0);
  test_assert(isnan([number("NaN") float64Value]));

  // Those which aren't numbers
  const char *invalid[] = {"",     " 42", "42 ", "4 2",  "abc", "True", "FALSE",
                           "inf",  "nan", "1e",  "+.",   "0x",  "0b2",  "1.2.3",
                           "--1",  "0x1.5", "1,000", "\"42\""};
  for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
    test_assert(number(invalid[i]) == nil);
  }
  test_assert([NXNumber numberWithString:nil] == nil);

  // Constant strings with a zero in them
  test_assert([NXNumber numberWithString:@"true\0junk"] == nil);
  test_assert([NXNumber numberWithString:@"false\0"] == nil);
  test_assert([NXNumber numberWithString:@"42\0"] == nil);

  // Integers in other bases which don't fit, rather than floats
  const char *overflow[] = {"0x10000000000000000",  "-0x8000000000000001",
                            "0b" "1" "0000000000000000000000000000000000000000000000000000000000000000",
                            "0o2000000000000000000000",
                            "02000000000000000000000",
                            "-01000000000000000000001"};
  for (size_t i = 0; i < sizeof(overflow) / sizeof(overflow[0]); i++) {
    test_assert(number(overflow[i]) == nil);
  }

  // Leading zeros of floats, and decimal integers which don't fit
  test_assert([number("0755.5") float64Value] == 755.5);
  test_assert([number("07e2") float64Value] == 700.0);
  test_assert([number("00.5") float64Value] == 0.5);
  n = number("99999999999999999999");
  test_assert([n isFloat] && [n float64Value] > 9.9999e19 &&
              [n float64Value] < 1.0001e20);
}

static void strings(NXZone *zone) {
  // Both quotes, and every escape
  NXString *string = unquote("\"hello\"");
  test_assert([string zone] == zone);
  test_assert_strequal([string cStr], "hello");
  test_assert_strequal([unquote("'hello'") cStr], "hello");
  test_assert_strequal([unquote("\"\"") cStr], "");
  test_assert([unquote("''") length] == 0);
  test_assert_strequal([unquote("\"a\\\"b\\\\c\\/d\"") cStr], "a\"b\\c/d");
  test_assert_strequal([unquote("'it\\'s'") cStr], "it's");
  test_assert_strequal([unquote("\"\\b\\f\\n\\r\\t\"") cStr], "\b\f\n\r\t");
  test_assert_strequal([unquote("\"\\u0041\\u00e9\\u20AC\"") cStr], "A\xC3\xA9\xE2\x82\xAC");
  test_assert_strequal([unquote("\"\xC3\xA9t\xC3\xA9\"") cStr], "\xC3\xA9t\xC3\xA9");

  // A zero ends it
  string = unquote("\"ab\\u0000cd\"");
  test_assert_strequal([string cStr], "ab");
  test_assert([string length] == 2);
  test_assert([unquote("\"\\u0000\"") length] == 0);

  // From a mutable string, and to one
  NXMutableString *mutable = [NXMutableString stringWithCString:"'x'"];
  test_assert_strequal([[NXString stringWithQuotedString:mutable] cStr], "x");
  mutable = [NXMutableString stringWithQuotedString:@"\"abc\""];
  test_assert(mutable != nil && [mutable appendCString:"def"]);
  test_assert_strequal([mutable cStr], "abcdef");

  // Those which aren't quoted strings
  const char *invalid[] = {"",        "hello",    "\"",       "'",      "\"open",
                           "\"a\\\"", "\"a\"b",   "\"a\" ",   " \"a\"", "\"a'",
                           "\"\\x\"", "\"\\u12\"", "\"\\uD800\"", "'a\"", "\"a\\\""};
  for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
    test_assert(unquote(invalid[i]) == nil);
  }
  test_assert([NXString stringWithQuotedString:nil] == nil);

  // With a scanner
  NXScanner *scanner = [NXScanner scannerWithString:@"x = 'a\\'b' 42 0x10 2.5 true"
                                              flags:NXScannerKeywords | NXScannerQuotes |
                                                    NXScannerNumbersHex |
                                                    NXScannerNumbersFloat];
  test_assert(scanner != nil);
  int strings = 0, numbers = 0;
  while ([scanner next]) {
    if ([scanner tokenClass] == NXScannerClassString) {
      test_assert_strequal([[NXString stringWithQuotedString:[scanner token]] cStr],
                           "a'b");
      strings++;
    } else if ([scanner tokenClass] == NXScannerClassNumber) {
      test_assert([NXNumber numberWithString:[scanner token]] != nil);
      numbers++;
    }
  }
  test_assert(strings == 1 && numbers == 3);
}

test_main(0) {
  for (int i = 0; i < 3; i++) {
    NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
    numbers();
    strings(nil);
    [pool release];
  }

  NXZone *zone = [NXZone zoneWithSize:8192];
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  numbers();
  strings(zone);
  [pool release];
  test_assert([zone count] == 0);
  [zone release];
}
