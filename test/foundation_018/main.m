#include <Foundation/Foundation.h>
#include <test/test.h>

#ifndef SYSTEM_NAME_PICO
#include <unistd.h>
#endif

static const struct {
  const char *string, *md5, *sha256;
} vectors[] = {
    {"hello world",
     "5eb63bbbe01eeed093cb22bb8f5acdc3",
     "b94d27b9934d3e08a52e52d7da7dabfa"
     "c484efe37a5380ee9088f7ace2efcde9"},
    {"",
     "d41d8cd98f00b204e9800998ecf8427e",
     "e3b0c44298fc1c149afbf4c8996fb924"
     "27ae41e4649b934ca495991b7852b855"},
    {"abc",
     "900150983cd24fb0d6963f7d28e17f72",
     "ba7816bf8f01cfea414140de5dae2223"
     "b00361a396177a9cb410ff61f20015ad"},
};

// Of "0,1,2,..." up to 999, and of every byte in order
#define LONG_MD5 "2b76db6220514739f82925b1082bd277"
#define LONG_SHA256 \
  "c76dd6f3c17103439dfb85094b25f725" \
      "c8a46fabf6288b0b9e6743774739eb3e"
#define BYTES_MD5 "e2c865db4162bed963bfaa9ef6ac18f0"
#define BYTES_SHA256 \
  "40aff2e9d2d8922e47afd4648e696749" \
      "7158785fbd1da870e7110266bf944880"

static void check(NXStream *stream, NXHashAlgorithm algorithm,
                  const char *expected) {
  NXString *hash = [stream hashWithAlgorithm:algorithm];
  test_assert_strequal([hash cStr], expected);
  test_assert([hash length] == strlen(expected));
}

static void hashes(void) {
  for (size_t i = 0; i < sizeof(vectors) / sizeof(vectors[0]); i++) {
    NXString *string = [NXString stringWithCString:vectors[i].string];
    NXStream *stream = [NXStream streamWithString:string];
    check(stream, NXHashAlgorithmMD5, vectors[i].md5);

    // It's then at the end
    test_assert([stream position] == [string length]);
    check(stream, NXHashAlgorithmMD5, vectors[1].md5);
    check(stream, NXHashAlgorithmSHA256, vectors[1].sha256);

    // It can be hashed again from the start, and peeking makes no difference
    test_assert([stream seek:0 relative:NO]);
    [stream peek];
    check(stream, NXHashAlgorithmSHA256, vectors[i].sha256);
    [stream close];
  }

  // Only the rest of it is
  NXStream *stream = [NXStream streamWithString:@"xyzabc"];
  test_assert([stream seek:3 relative:NO]);
  check(stream, NXHashAlgorithmMD5, vectors[2].md5);
  test_assert([[stream hashWithAlgorithm:NXHashAlgorithmMD5]
      isEqual:[NXString stringWithCString:vectors[1].md5]]);
  [stream close];

  // A long one
  NXMutableString *mutable = [NXMutableString string];
  for (int i = 0; i < 1000; i++) {
    test_assert([mutable appendFormat:@"%d,", i]);
  }
  stream = [NXStream streamWithString:mutable];
  check(stream, NXHashAlgorithmMD5, LONG_MD5);
  test_assert([stream seek:0 relative:NO]);
  check(stream, NXHashAlgorithmSHA256, LONG_SHA256);
  [stream close];

  // Memory, with every byte
  stream = [NXStream streamWithCapacity:256];
  for (int i = 0; i < 256; i++) {
    unsigned char byte = (unsigned char)i;
    test_assert([stream writeBytes:&byte length:1] == 1);
  }
  test_assert([stream seek:0 relative:NO]);
  check(stream, NXHashAlgorithmMD5, BYTES_MD5);
  test_assert([stream seek:0 relative:NO]);
  check(stream, NXHashAlgorithmSHA256, BYTES_SHA256);
  [stream close];

  // As bytes
  uint8_t bytes[NXHashMaxSize + 1];
  memset(bytes, 0xAA, sizeof(bytes));
  stream = [NXStream streamWithString:@"abc"];
  test_assert([stream hashWithAlgorithm:NXHashAlgorithmMD5 bytes:bytes] == 16);
  test_assert(bytes[0] == 0x90 && bytes[15] == 0x72 && bytes[16] == 0xAA);
  test_assert([stream seek:0 relative:NO]);
  test_assert([stream hashWithAlgorithm:NXHashAlgorithmSHA256 bytes:bytes] == 32);
  test_assert(bytes[0] == 0xba && bytes[31] == 0xad && bytes[32] == 0xAA);

  // Those which aren't available
  test_assert([stream hashWithAlgorithm:(NXHashAlgorithm)99] == nil);
  test_assert([stream hashWithAlgorithm:(NXHashAlgorithm)99 bytes:bytes] == 0);
  [stream close];
  test_assert([stream hashWithAlgorithm:NXHashAlgorithmMD5] == nil);
}

// Two threads at the same time
static sys_waitgroup_t *wg = NULL;
static sys_atomic_t ready;

static void work(void) {
  sys_atomic_inc(&ready);
  while (sys_atomic_get(&ready) < 2) {
  }
  for (int i = 0; i < 100; i++) {
    NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
    NXStream *stream = [NXStream streamWithString:@"abc"];
    check(stream, NXHashAlgorithmMD5, vectors[2].md5);
    test_assert([stream seek:0 relative:NO]);
    check(stream, NXHashAlgorithmSHA256, vectors[2].sha256);
    [pool release];
  }
}

static void thread(void *arg) {
  (void)arg;
  work();
  sys_waitgroup_done(wg);
}

test_main(0) {
  // More than once, so that it's known that nothing is left in use
  for (int i = 0; i < 10; i++) {
    NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
    hashes();
    [pool release];
  }

  wg = sys_waitgroup_init();
  test_assert(wg != NULL && sys_waitgroup_add(wg, 1));
  test_assert(sys_thread_create(thread, NULL));
  work();
  sys_waitgroup_wait(wg);
  sys_waitgroup_deinit(wg);

#ifndef SYSTEM_NAME_PICO
  // Standard input, as far as its end, including what's been peeked at
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  int fds[2];
  test_assert(pipe(fds) == 0 && dup2(fds[0], 0) == 0);
  test_assert(write(fds[1], "abc", 3) == 3 && close(fds[1]) == 0);
  NXStream *input = [NXStream standardInput];
  test_assert([input peek] == 'a');
  check(input, NXHashAlgorithmSHA256, vectors[2].sha256);
  test_assert([input peek] == NXStreamEnd);
  check(input, NXHashAlgorithmMD5, vectors[1].md5);
  [pool release];
#endif
}
