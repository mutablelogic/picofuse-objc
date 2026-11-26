// NXDebug in a debug build
#undef NDEBUG
#include <Foundation/Foundation.h>
#include <string.h>
#include <test/test.h>

#ifndef SYSTEM_NAME_PICO
#include <stdio.h>
#include <unistd.h>
#endif

int debug_in_release(int *evaluated);

// An object whose description logs, and one whose description logs itself
@interface Logging : NXObject
@end

@implementation Logging
- (NXString *)description {
  NXLog(@"describing");
  return @"logging";
}
@end

@interface Recursive : NXObject
@end

@implementation Recursive
- (NXString *)description {
  NXLog(@"%@", self);
  return @"recursive";
}
@end

#ifndef SYSTEM_NAME_PICO
// Standard output, in a pipe, while it's captured
static int saved = -1, fds[2];

// picofuse writes to the standard output of C, which is flushed before it's swapped
static void capture(void) {
  fflush(stdout);
  test_assert(pipe(fds) == 0);
  saved = dup(1);
  test_assert(saved >= 0 && dup2(fds[1], 1) == 1);
}

// Returns what was written, as a string
static NXString *captured(void) {
  fflush(stdout);
  test_assert(dup2(saved, 1) == 1 && close(saved) == 0 && close(fds[1]) == 0);
  NXMutableString *string = [NXMutableString string];
  char buffer[257];
  ssize_t n;
  while ((n = read(fds[0], buffer, sizeof(buffer) - 1)) > 0) {
    buffer[n] = '\0';
    test_assert([string appendCString:buffer]);
  }
  close(fds[0]);
  return string;
}
#endif

static void logging(void) {
  // Formats, and lines
  test_assert(NXLog(@"hello") == 6);
  test_assert(NXLog(@"%d %@ %t", 42, @"world", 90 * NXSecond) == 15);
  test_assert(NXDebug(@"debug %d", 1) == 16);

  // A description which logs, whose line comes first
  test_assert(NXLog(@"[%@]", [[[Logging alloc] init] autorelease]) == 10);

  // A description which logs itself is stopped
  test_assert(NXLog(@"%@", [[[Recursive alloc] init] autorelease]) == 10);

  // A long line, which doesn't fit in the buffer for formatting
  NXMutableString *longer = [NXMutableString string];
  for (int i = 0; i < 100; i++) {
    test_assert([longer appendCString:"0123456789"]);
  }
  test_assert(NXLog(@"%@", longer) == 1001);
}

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];

#ifndef SYSTEM_NAME_PICO
  capture();
  logging();
  NXString *output = captured();
  NXMutableString *expected = [NXMutableString
      stringWithCString:"hello\n42 world 1m30s\n[DEBUG] debug 1\ndescribing\n"
                        "[logging]\n[NXLog] nested more than 4 deep\n"
                        "recursive\nrecursive\nrecursive\nrecursive\n"];
  for (int i = 0; i < 100; i++) {
    test_assert([expected appendCString:"0123456789"]);
  }
  test_assert([expected appendCString:"\n"]);
  test_assert([output isEqual:expected]);
#else
  logging();
#endif

  // In a release build, the arguments aren't evaluated
  int evaluated = 0;
  test_assert(debug_in_release(&evaluated) == 0 && evaluated == 0);

  [pool release];
}
