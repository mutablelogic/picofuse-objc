#include <Foundation/Foundation.h>
#include <test/test.h>

#ifndef SYSTEM_NAME_PICO
#include <unistd.h>
#endif

// Returns how many streams can be opened
static int available(void) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  int count = 0;
  while (count < 100 && [NXStream streamWithString:@"string"] != nil) {
    count++;
  }
  [pool release];
  return count;
}

// Reading a string
static void reading(NXStream *stream, size_t length) {
  char bytes[8] = "xxxxxxx";
  test_assert(stream != nil && ![stream isClosed] && length >= 8);
  test_assert([stream position] == 0 && [stream peek] == 'h');
  test_assert([stream peek] == 'h' && [stream position] == 0);
  test_assert([stream readBytes:bytes length:0] == 0 && bytes[0] == 'x');
  test_assert([stream readBytes:bytes length:3] == 3);
  test_assert(memcmp(bytes, "helx", 4) == 0 && [stream position] == 3);

  // The position
  test_assert([stream seek:1 relative:NO] && [stream peek] == 'e');
  test_assert([stream seek:2 relative:YES] && [stream peek] == 'l');
  test_assert([stream seek:-3 relative:YES] && [stream peek] == 'h');
  test_assert(![stream seek:-1 relative:YES] && [stream position] == 0);
  test_assert(![stream seek:length + 1 relative:NO] && [stream position] == 0);
  test_assert(![stream seek:PTRDIFF_MAX relative:NO]);
  test_assert(![stream seek:-1 relative:NO] && [stream position] == 0);
  test_assert([stream seek:length relative:NO] && [stream position] == length);
  test_assert(![stream seek:1 relative:YES]);

  // The end
  test_assert([stream peek] == NXStreamEnd && ![stream isEnded]);
  test_assert([stream readBytes:bytes length:4] == 0);
  test_assert([stream readStringWithLength:4] == nil);
  test_assert([stream seek:length - 2 relative:NO]);
  test_assert([stream readBytes:bytes length:8] == 2);

  // As a string
  test_assert([stream seek:0 relative:NO]);
  test_assert([stream readStringWithLength:0] == nil);
  test_assert([[stream readStringWithLength:5] isEqual:@"hello"]);
  test_assert([[stream readStringWithLength:1] isEqual:@" "]);
  test_assert([stream position] == 6);
  NXString *rest = [stream readStringWithLength:SIZE_MAX];
  test_assert([rest length] == length - 6);
}

// Close those which have been used so far, as there can't be many
static void drain(void) { [[NXAutoreleasePool currentPool] drain]; }

static void streams(NXZone *zone) {
  int limit = available();
  test_assert(limit > 0 && limit < 100);

  // A string, which can't be written
  NXStream *stream = [NXStream streamWithString:@"hello world"];
  test_assert([stream zone] == zone);
  reading(stream, 11);
  test_assert([stream writeString:@"x"] == 0);
  test_assert([[NXStream streamWithString:@""] peek] == NXStreamEnd);

  // A long one
  drain();
  NXMutableString *mutable = [NXMutableString stringWithCString:"hello "];
  for (int i = 0; i < 500; i++) {
    test_assert([mutable appendFormat:@"%d", i % 10]);
  }
  stream = [NXStream streamWithString:mutable];
  reading(stream, 506);
  test_assert([stream seek:0 relative:NO]);
  test_assert([[stream readStringWithLength:1000] isEqual:mutable]);

  // It's not affected by the string being changed, or released
  drain();
  mutable = [[NXMutableString alloc] initWithCString:"before"];
  stream = [NXStream streamWithString:mutable];
  [mutable toUppercase];
  for (int i = 0; i < 100; i++) {
    test_assert([mutable appendCString:"after"]);
  }
  [mutable release];
  test_assert([[stream readStringWithLength:100] isEqual:@"before"]);
  NXString *string = [[NXString alloc] initWithFormat:@"%d", 12345];
  stream = [NXStream streamWithString:string];
  [string release];
  test_assert([[stream readStringWithLength:100] isEqual:@"12345"]);

  // Memory, which starts empty
  drain();
  stream = [NXStream streamWithCapacity:20];
  test_assert([stream peek] == NXStreamEnd && [stream position] == 0);
  test_assert([stream writeString:@"hello "] == 6);
  test_assert([stream writeBytes:"world!!" length:5] == 5);
  test_assert([stream peek] == NXStreamEnd && [stream position] == 11);
  test_assert([stream seek:0 relative:NO]);
  reading(stream, 11);

  // It's only written as far as there's room
  test_assert([stream seek:11 relative:NO]);
  test_assert([stream writeString:@"0123456789"] == 9);
  test_assert([stream writeString:@"x"] == 0);
  test_assert([stream seek:0 relative:NO]);
  test_assert([[stream readStringWithLength:99]
      isEqual:@"hello world012345678"]);
  test_assert([stream seek:6 relative:NO] && [stream writeString:@"W"] == 1);
  test_assert([stream seek:0 relative:NO]);
  test_assert([[stream readStringWithLength:11] isEqual:@"hello World"]);

  // Bytes which aren't a string
  drain();
  stream = [NXStream streamWithCapacity:4];
  test_assert([stream writeBytes:"a\0\xFF" "b" length:4] == 4);
  test_assert([stream seek:1 relative:NO] && [stream peek] == 0);
  test_assert([stream seek:2 relative:NO] && [stream peek] == 0xFF);
  test_assert([stream seek:0 relative:NO]);
  test_assert([[stream readStringWithLength:4] isEqual:@"a"]);
  test_assert([stream position] == 4);
  stream = [NXStream streamWithCapacity:0];
  test_assert(stream != nil && [stream writeString:@"x"] == 0);

  // A stream from picofuse
  drain();
  stream = [[[NXStream alloc] initWithStream:sys_string_read("hello world")]
      autorelease];
  reading(stream, 11);
  test_assert([[NXStream alloc] initWithStream:NULL] == nil);

  // Closing
  int before = available();
  [stream close];
  test_assert([stream isClosed] && [stream isEnded]);
  test_assert(available() == before + 1);
  [stream close];
  test_assert(available() == before + 1);
  char byte;
  test_assert([stream peek] == NXStreamEnd && [stream position] == NXNotFound);
  test_assert([stream readBytes:&byte length:1] == 0);
  test_assert([stream readStringWithLength:1] == nil);
  test_assert([stream writeString:@"x"] == 0);
  test_assert(![stream seek:0 relative:NO] && ![stream seek:0 relative:YES]);

  // A zero byte ends a string, even after more than is read at a time
  drain();
  stream = [NXStream streamWithCapacity:200];
  test_assert([stream writeBytes:"a" length:2] == 2);
  for (int i = 0; i < 100; i++) {
    test_assert([stream writeString:@"-"] == 1);
  }
  test_assert([stream writeString:@"tail"] == 4);
  test_assert([stream seek:0 relative:NO]);
  test_assert([[stream readStringWithLength:200] isEqual:@"a"]);

  // One which isn't initialized with anything is closed
  stream = [[[NXStream alloc] init] autorelease];
  test_assert([stream isClosed] && [stream isEnded]);
  test_assert([stream peek] == NXStreamEnd);
  test_assert([stream readBytes:&byte length:1] == 0);
  test_assert([stream readStringWithLength:1] == nil);
  test_assert(![stream seek:0 relative:YES] && [stream position] == NXNotFound);

  // Those which cannot be made
  test_assert([NXStream streamWithString:nil] == nil);
  test_assert([NXStream streamWithCapacity:SIZE_MAX] == nil);
}

test_main(0) {
  int limit = available();
  for (int i = 0; i < 3; i++) {
    NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
    streams(nil);
    [pool release];
    test_assert(available() == limit);
  }

  NXZone *zone = [NXZone zoneWithSize:8192];
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  streams(zone);
  [pool release];
  test_assert([zone count] == 0 && available() == limit);
  [zone release];

  // Standard output isn't closed
  pool = [[NXAutoreleasePool alloc] init];
  for (int i = 0; i < 3; i++) {
    NXStream *output = [NXStream standardOutput];
    test_assert(output != nil && [output writeString:@"output\n"] == 7);
    [output close];
    test_assert([output isClosed] && [output writeString:@"not\n"] == 0);
  }
  test_assert([[NXStream standardOutput] writeString:@"again\n"] == 6);

#ifndef SYSTEM_NAME_PICO
  // Standard input, from a pipe, which doesn't have a position
  int fds[2];
  test_assert(pipe(fds) == 0 && dup2(fds[0], 0) == 0);
  NXStream *input = [NXStream standardInput];
  test_assert(input != nil && [input position] == NXNotFound);
  test_assert(![input seek:0 relative:NO] && ![input seek:1 relative:YES]);
  test_assert(write(fds[1], "abc", 3) == 3);
  test_assert([input peek] == 'a' && [input peek] == 'a');
  char bytes[4];
  test_assert([input readBytes:bytes length:4] == 1 && bytes[0] == 'a');
  test_assert([input readBytes:bytes length:4] == 2);
  test_assert(bytes[0] == 'b' && bytes[1] == 'c');

  // It doesn't wait for more than there is
  test_assert(write(fds[1], "def", 3) == 3);
  test_assert([[input readStringWithLength:100] isEqual:@"def"]);
  test_assert(write(fds[1], "g", 1) == 1 && [input peek] == 'g');
  test_assert([[input readStringWithLength:100] isEqual:@"g"]);

  // What's peeked at is kept for every stream of it, even when one is closed
  test_assert(write(fds[1], "hij", 3) == 3);
  NXStream *other = [NXStream standardInput];
  test_assert([input peek] == 'h' && [other peek] == 'h');
  test_assert([other readBytes:bytes length:1] == 1 && bytes[0] == 'h');
  test_assert([input peek] == 'i');
  [input close];
  test_assert([input peek] == NXStreamEnd);
  test_assert([other readBytes:bytes length:1] == 1 && bytes[0] == 'i');
  test_assert(![other seek:-1 relative:YES]);
  test_assert([other readBytes:bytes length:4] == 1 && bytes[0] == 'j');
  input = other;

  // Until the end
  test_assert(close(fds[1]) == 0);
  test_assert([input peek] == NXStreamEnd);
  test_assert([input readStringWithLength:100] == nil);
#endif

  [pool release];
}
