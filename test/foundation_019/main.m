#include <Foundation/Foundation.h>
#include <test/test.h>

#ifndef SYSTEM_NAME_PICO
#include <unistd.h>
#endif

typedef struct {
  NXScannerClass isa;
  const char *token;
} token_t;

// Scan everything, and check each token is as expected
static void scan(NXScanner *scanner, const token_t *tokens, size_t count) {
  test_assert(scanner != nil);
  size_t position = [[scanner stream] position];
  for (size_t i = 0; i < count; i++) {
    test_assert([scanner next]);
    NXString *token = [scanner token];
    test_assert_strequal([token cStr], tokens[i].token);
    test_assert([scanner tokenClass] == tokens[i].isa);
    test_assert([scanner tokenLength] == strlen(tokens[i].token));
    test_assert([scanner tokenRuneCount] == [token runeCount]);
    test_assert([scanner tokenPosition] == position);
    position += [scanner tokenLength];
    test_assert([[scanner stream] position] == position);
  }

  // Then there's nothing
  for (int i = 0; i < 2; i++) {
    test_assert(![scanner next]);
    test_assert([scanner token] == nil && [scanner tokenLength] == 0);
    test_assert([scanner tokenClass] == NXScannerClassOther);
    test_assert([scanner tokenRuneCount] == 0);
    test_assert([scanner tokenPosition] == NXNotFound);
  }
}

#define SCAN(scanner, ...)                                                     \
  do {                                                                         \
    static const token_t tokens[] = {__VA_ARGS__};                             \
    scan(scanner, tokens, sizeof(tokens) / sizeof(tokens[0]));                 \
  } while (0)

// Close those which have been used so far, as there can't be many streams
static void drain(void) { [[NXAutoreleasePool currentPool] drain]; }

static void scanners(NXZone *zone) {
  // Without flags, only runs of spaces, letters and digits
  NXScanner *scanner = [NXScanner scannerWithString:@"x1 = 42, \xC3\xA9t\xC3\xA9!"
                                              flags:NXScannerNone];
  test_assert([scanner zone] == zone && [[scanner stream] zone] == zone);
  test_assert([scanner tokenClass] == NXScannerClassOther);
  test_assert([scanner token] == nil && [scanner tokenPosition] == NXNotFound);
  SCAN(scanner, {NXScannerClassAlpha, "x"}, {NXScannerClassDigit, "1"},
       {NXScannerClassSpace, " "}, {NXScannerClassSymbol, "="},
       {NXScannerClassSpace, " "}, {NXScannerClassDigit, "42"},
       {NXScannerClassPunct, ","}, {NXScannerClassSpace, " "},
       {NXScannerClassAlpha, "\xC3\xA9t\xC3\xA9"}, {NXScannerClassPunct, "!"});

  drain();
  // Characters of more than one byte
  scanner = [NXScanner scannerWithString:@"\xC3\xA9t\xC3\xA9" flags:NXScannerNone];
  test_assert([scanner next] && [scanner tokenLength] == 5);
  test_assert([scanner tokenRuneCount] == 3);

  drain();
  // Keywords, numbers and comments
  scanner = [NXScanner
      scannerWithString:@"x_1 = -42 // answer\n# hash\nmy-name"
                  flags:NXScannerKeywordsWithUnderscores | NXScannerNumbers |
                        NXScannerComments | NXScannerNewlines];
  SCAN(scanner, {NXScannerClassKeyword, "x_1"}, {NXScannerClassSpace, " "},
       {NXScannerClassSymbol, "="}, {NXScannerClassSpace, " "},
       {NXScannerClassNumber, "-42"}, {NXScannerClassSpace, " "},
       {NXScannerClassComment, "// answer"}, {NXScannerClassNewline, "\n"},
       {NXScannerClassComment, "# hash"}, {NXScannerClassNewline, "\n"},
       {NXScannerClassKeyword, "my"}, {NXScannerClassPunct, "-"},
       {NXScannerClassKeyword, "name"});
  scanner = [NXScanner scannerWithString:@"my-name\n"
                                   flags:NXScannerKeywordsWithDashes];
  SCAN(scanner, {NXScannerClassKeyword, "my-name"}, {NXScannerClassSpace, "\n"});

  drain();
  // Numbers of every kind
  scanner = [NXScanner scannerWithString:@"0x1F 0b101 0o17 3.14 1e-3"
                                   flags:NXScannerNumbersHex | NXScannerNumbersBinary |
                                         NXScannerNumbersOctal | NXScannerNumbersFloat];
  SCAN(scanner, {NXScannerClassNumber, "0x1F"}, {NXScannerClassSpace, " "},
       {NXScannerClassNumber, "0b101"}, {NXScannerClassSpace, " "},
       {NXScannerClassNumber, "0o17"}, {NXScannerClassSpace, " "},
       {NXScannerClassNumber, "3.14"}, {NXScannerClassSpace, " "},
       {NXScannerClassNumber, "1e-3"});

  drain();
  // Strings and escapes
  scanner = [NXScanner scannerWithString:@"\"a \\\"b\\\"\" 'c' \\n\\u0041 'open"
                                   flags:NXScannerQuotes | NXScannerEscapes];
  SCAN(scanner, {NXScannerClassString, "\"a \\\"b\\\"\""}, {NXScannerClassSpace, " "},
       {NXScannerClassString, "'c'"}, {NXScannerClassSpace, " "},
       {NXScannerClassEscape, "\\n"}, {NXScannerClassEscape, "\\u0041"},
       {NXScannerClassSpace, " "}, {NXScannerClassString, "'open"});
  scanner = [NXScanner scannerWithString:@"'c' \"d\"" flags:NXScannerQuotesDouble];
  SCAN(scanner, {NXScannerClassPunct, "'"}, {NXScannerClassAlpha, "c"},
       {NXScannerClassPunct, "'"}, {NXScannerClassSpace, " "},
       {NXScannerClassString, "\"d\""});

  drain();
  // Nothing
  SCAN([NXScanner scannerWithString:@"" flags:NXScannerNone]);

  drain();
  // A stream, from its position, which can be read between tokens
  NXStream *stream = [NXStream streamWithString:@"skip one two three"];
  test_assert([stream seek:5 relative:NO]);
  scanner = [NXScanner scannerWithStream:stream flags:NXScannerKeywords];
  test_assert([scanner stream] == stream);
  test_assert([scanner next] && [[scanner token] isEqual:@"one"]);
  test_assert([scanner tokenPosition] == 5 && [stream position] == 8);
  test_assert([stream seek:1 relative:YES]);
  test_assert([scanner next] && [[scanner token] isEqual:@"two"]);
  test_assert([scanner tokenClass] == NXScannerClassKeyword);
  test_assert([stream seek:0 relative:NO]);
  test_assert([[scanner token] isEqual:@"two"] && [stream position] == 0);
  test_assert([scanner next] && [[scanner token] isEqual:@"skip"]);

  // A closed stream has nothing
  [stream close];
  test_assert([scanner token] == nil && ![scanner next]);
  test_assert([scanner tokenClass] == NXScannerClassOther);

  drain();
  // Those which cannot be made
  test_assert([NXScanner scannerWithString:nil flags:NXScannerNone] == nil);
  test_assert([NXScanner scannerWithStream:nil flags:NXScannerNone] == nil);
  stream = [NXStream streamWithString:@"x"];
  [stream close];
  test_assert([NXScanner scannerWithStream:stream flags:NXScannerNone] == nil);
}

test_main(0) {
  for (int i = 0; i < 3; i++) {
    NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
    scanners(nil);
    [pool release];
  }

  NXZone *zone = [NXZone zoneWithSize:8192];
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  scanners(zone);
  [pool release];
  test_assert([zone count] == 0);
  [zone release];

  // Many, one after another, so that streams aren't left open
  for (int i = 0; i < 100; i++) {
    pool = [[NXAutoreleasePool alloc] init];
    NXScanner *scanner = [NXScanner scannerWithString:@"a b" flags:NXScannerNone];
    test_assert([scanner next] && [[scanner token] isEqual:@"a"]);
    [pool release];
  }

#ifndef SYSTEM_NAME_PICO
  // Standard input from a pipe doesn't have a position
  int fds[2];
  test_assert(pipe(fds) == 0 && dup2(fds[0], 0) == 0);
  pool = [[NXAutoreleasePool alloc] init];
  test_assert([NXScanner scannerWithStream:[NXStream standardInput]
                                     flags:NXScannerNone] == nil);
  [pool release];
#endif
}
