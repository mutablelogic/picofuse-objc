#include <Foundation/Foundation.h>
#include <test/test.h>

@protocol Missing
- (void)missing;
@end

// Counts how often its description is needed, and it's different each time
@interface Changing : NXObject {
@public
  int _count;
  BOOL _longer;
}
@end

@implementation Changing
- (NXString *)description {
  return (_count++ == 0) == _longer ? @"abcdef" : @"ab";
}
@end

// Formats its description
@interface Nested : NXObject
@end

@implementation Nested
- (NXString *)description {
  return [NXString stringWithFormat:@"(%@ %d)", [NXNumber numberWithInt16:7], 8];
}
@end

// Its -init uses each initializer of its superclass
@interface Default : NXMutableString {
  int _number;
}
- (id)initWithNumber:(int)number;
@end

@implementation Default
- (id)initWithNumber:(int)number {
  _number = number;
  return [self init];
}
- (id)init {
  if (_number == 0) {
    return [super initWithCString:"default"];
  } else if (_number == 1) {
    return [super initWithString:@"default"];
  } else if (_number == -1) {
    return [super initWithCapacity:50];
  }
  return _number < 100 ? [super initWithFormat:@"%d", _number]
                       : [super initWithFormat:@"%300d", _number];
}
@end

static NXString *format_list(NXString *format, ...) {
  va_list args;
  va_start(args, format);
  NXString *string = [[NXString alloc] initWithFormat:format arguments:args];
  va_end(args);
  return [string autorelease];
}

static void strings(NXZone *zone) {
  // From other strings, which are copied
  char buffer[] = "hello";
  NXString *string = [NXString stringWithCString:buffer];
  buffer[0] = 'j';
  test_assert_strequal([string cStr], "hello");
  test_assert([string length] == 5 && [string zone] == zone);
  test_assert([string isKindOfClass:[NXString class]]);
  test_assert(![string isKindOfClass:[NXMutableString class]]);
  test_assert([string isEqual:@"hello"] && [@"hello" isEqual:string]);
  test_assert(![string isEqual:@"jello"] && ![string isEqual:@"hell"]);
  test_assert([[NXString stringWithString:@"abc"] isEqual:@"abc"]);
  test_assert([[NXString stringWithString:string] isEqual:string]);

  // Empty
  test_assert([[NXString string] length] == 0);
  test_assert_strequal([[NXString string] cStr], "");
  test_assert([[NXString stringWithCString:NULL] isEqual:@""]);
  test_assert([[NXString stringWithCString:""] isEqual:@""]);
  test_assert([[NXString stringWithString:nil] isEqual:@""]);
  test_assert([[NXString stringWithFormat:@""] isEqual:@""]);
  test_assert([[NXString stringWithFormat:nil] isEqual:@""]);

  // Bytes, as far as zero
  string = [[NXString alloc] initWithBytes:"abcd" length:3];
  test_assert([string isEqual:@"abc"] && [string length] == 3);
  [string release];
  string = [[NXString alloc] initWithBytes:"a\0b" length:3];
  test_assert([string isEqual:@"a"] && [string length] == 1);
  test_assert([[NXString stringWithFormat:@"%@c", string] isEqual:@"ac"]);
  [string release];
  string = [[NXString alloc] initWithBytes:"\0b" length:2];
  test_assert([string isEqual:@""] && [string length] == 0);
  [string release];
  test_assert([[NXString stringWithFormat:@"a%cb", 0] isEqual:@"a"]);
  test_assert([[NXString stringWithFormat:@"a%c%200d", 0, 1] isEqual:@"a"]);
  NXMutableString *mutable = [NXMutableString stringWithFormat:@"a%cb", 0];
  test_assert([mutable appendFormat:@"c%cd", 0]);
  test_assert([mutable appendFormat:@"e%c%200d", 0, 1]);
  test_assert([mutable isEqual:@"ace"] && [mutable length] == 3);

  // Subclasses which have an initializer of their own
  Default *initialized = [[[Default alloc] initWithNumber:1] autorelease];
  test_assert([initialized isEqual:@"default"]);
  initialized = [[[Default alloc] initWithNumber:2] autorelease];
  test_assert([initialized isEqual:@"2"]);
  initialized = [[[Default alloc] initWithNumber:300] autorelease];
  test_assert([initialized length] == 300);
  initialized = [[[Default alloc] initWithNumber:-1] autorelease];
  test_assert([initialized isEqual:@""] && [initialized capacity] == 50);
  initialized = [[[Default alloc] init] autorelease];
  test_assert([initialized isEqual:@"default"]);

  // Formats
  test_assert([[NXString stringWithFormat:@"%d %s %c %x", -42, "str", 'c', 255]
      isEqual:@"-42 str c ff"]);
  test_assert([[NXString stringWithFormat:@"%ld %lu", INT64_MIN, UINT64_MAX]
      isEqual:@"-9223372036854775808 18446744073709551615"]);
  test_assert([[NXString stringWithFormat:@"100%%"] isEqual:@"100%"]);
  test_assert([format_list(@"%s-%d", "list", 7) isEqual:@"list-7"]);

  // Objects
  test_assert([[NXString stringWithFormat:@"<%@|%@>", @"constant",
                                          [NXString stringWithCString:"heap"]]
      isEqual:@"<constant|heap>"]);
  id none = nil;
  test_assert([[NXString stringWithFormat:@"%@ %d", none, 3]
      isEqual:@"<nil> 3"]);
  test_assert([[NXString stringWithFormat:@"%@", [NXNull nullValue]]
      isEqual:@"null"]);
  test_assert([[NXString stringWithFormat:@"%@", [NXNumber class]]
      isEqual:@"NXNumber"]);
  test_assert([[NXString stringWithFormat:@"%@", @protocol(Missing)]
      isEqual:@"Protocol"]);

  // A description which itself formats one
  test_assert([[NXString stringWithFormat:@"%@ and %@",
                                          [NXNumber numberWithInt16:-5],
                                          [NXNumber numberWithFloat64:2.5]]
      isEqual:@"-5 and 2.5"]);

  // Durations
  test_assert([[NXString stringWithFormat:@"%t, %t and %d",
                                          NXMinute + 5 * NXSecond,
                                          (NXDuration)0, 6]
      isEqual:@"1m 5s, 0s and 6"]);

  // What's documented
  string = [NXString stringWithFormat:@"%b %o %X %#x %05d %+d|%-4s|%4s|%.3f %zu",
                                      5, 8, 0xAB, 0xAB, 42, 42, "l", "r", 1.5,
                                      sizeof(uint32_t)];
  test_assert_strequal([string cStr], "101 10 AB 0xab 00042 +42|l   |   r|1.500 4");

  // A short string is only formatted once
  Changing *changing = [[[Changing alloc] init] autorelease];
  string = [NXString stringWithFormat:@"%@", changing];
  test_assert(changing->_count == 1 && [string isEqual:@"ab"]);
  string = [NXMutableString stringWithFormat:@"%@", changing];
  test_assert(changing->_count == 2 && [string isEqual:@"abcdef"]);
  test_assert([(NXMutableString *)string appendFormat:@"%@", changing]);
  test_assert(changing->_count == 3 && [string isEqual:@"abcdefabcdef"]);

  // A long one is formatted twice, and can be shorter or longer the second time
  for (int i = 0; i < 2; i++) {
    changing = [[[Changing alloc] init] autorelease];
    changing->_longer = i;
    string = [NXString stringWithFormat:@"%200d%@", 1, changing];
    test_assert(changing->_count == 2 && [string length] == 202);
    test_assert(strlen([string cStr]) == 202);
    changing->_count = 0;
    string = [NXMutableString string];
    test_assert([(NXMutableString *)string appendFormat:@"%200d%@", 1, changing]);
    test_assert(changing->_count == 2 && [string length] == 202);
    test_assert(strlen([string cStr]) == 202);
  }

  // Lengths either side of what's formatted once
  for (int length = 120; length < 136; length++) {
    NXMutableString *expected = [NXMutableString string];
    for (int i = 0; i < length; i++) {
      test_assert([expected appendCString:i % 2 ? "x" : "y"]);
    }
    string = [NXString stringWithFormat:@"%@", expected];
    test_assert([string isEqual:expected]);
    test_assert(strlen([string cStr]) == (size_t)length);
  }

  // Descriptions which are themselves formatted
  Nested *nested = [[[Nested alloc] init] autorelease];
  test_assert([[NXString stringWithFormat:@"%@%@%t", nested, nested, NXSecond]
      isEqual:@"(7 8)(7 8)1s"]);
  string = [NXString stringWithFormat:@"%@%200d", nested, 1];
  test_assert([string length] == 205);

  // Long
  string = [NXString stringWithFormat:@"%300d|", 1];
  test_assert([string length] == 301 && [string cStr][300] == '|');
}

// Two threads format strings at the same time
static sys_waitgroup_t *wg = NULL;
static sys_atomic_t ready;

static void work(int number) {
  sys_atomic_inc(&ready);
  while (sys_atomic_get(&ready) < 2) {
  }
  for (int i = 0; i < 500; i++) {
    NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
    NXNumber *object = [NXNumber numberWithInt32:number * 1000 + i];
    NXString *string = [NXString stringWithFormat:@"%d:%@", number, object];
    char expected[32];
    sys_sprintf(expected, sizeof(expected), "%d:%d", number, number * 1000 + i);
    test_assert_strequal([string cStr], expected);
    [pool release];
  }
}

static void thread(void *arg) {
  (void)arg;
  work(1);
  sys_waitgroup_done(wg);
}

static void threads(void) {
  wg = sys_waitgroup_init();
  test_assert(wg != NULL && sys_waitgroup_add(wg, 1));
  test_assert(sys_thread_create(thread, NULL));
  work(2);
  sys_waitgroup_wait(wg);
  sys_waitgroup_deinit(wg);
}

test_main(0) {
  threads();

  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  strings(nil);
  [pool release];

  NXZone *zone = [NXZone zoneWithSize:4096];
  pool = [[NXAutoreleasePool alloc] init];
  strings(zone);
  [pool release];
  test_assert([zone count] == 0);
  [zone release];
}
