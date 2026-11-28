// NXEnvironment and NXArgument: flags of every type, their defaults, positional
// arguments, why a command line doesn't parse, and usage
#include <Foundation/Foundation.h>
#include <test/test.h>

static NXArray *flags(void) {
  return [NXArray arrayWithObjects:
      [NXArgument argumentWithName:@"verbose" short:@"v"],
      [NXArgument argumentWithName:@"color" short:nil default:[NXNumber trueValue]],
      [NXArgument argumentWithName:@"count" short:@"n" default:[NXNumber numberWithInt32:3]],
      [NXArgument argumentWithName:@"big" short:nil default:[NXNumber numberWithUnsignedInt32:1]],
      [NXArgument argumentWithName:@"rate" short:nil default:[NXNumber numberWithFloat64:0.5]],
      [NXArgument argumentWithName:@"label" short:@"l" default:@"none"],
      [NXArgument argumentWithName:@"when" short:nil
                           default:[NXDate dateWithYear:2026 month:1 day:1]],
      [NXArgument argumentWithName:@"every" short:nil duration:NXSecond],
      nil];
}

static NXMap *parse(NXArray *argv_strings, NXEnvironment **environment, NXString **error) {
  static char *argv[16];
  size_t argc = [argv_strings count];
  test_assert(argc < 16);
  for (size_t i = 0; i < argc; i++) {
    argv[i] = (char *)[[argv_strings objectAtIndex:i] cStr];
  }
  argv[argc] = NULL;
  *environment = [NXEnvironment environmentWithArgc:(int)argc argv:argv];
  test_assert(*environment != nil);
  return [*environment parseFlags:flags() error:error];
}

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  NXEnvironment *environment = nil;
  NXString *error = nil;

  // Flags which can't be made
  test_assert([NXArgument argumentWithName:@"" short:nil] == nil);
  test_assert([NXArgument argumentWithName:nil short:nil] == nil);
  test_assert([NXArgument argumentWithName:@"x" short:@""] == nil);
  test_assert([NXArgument argumentWithName:@"x" short:nil default:nil] == nil);
  test_assert([NXArgument argumentWithName:@"x" short:nil default:[NXArray array]] == nil);
  // Zero defaults keep their kind, so these are a float and an unsigned flag
  NXArray *zeros = [NXArray
      arrayWithObjects:[NXArgument argumentWithName:@"rate" short:nil
                                            default:[NXNumber numberWithFloat64:0]],
                       [NXArgument argumentWithName:@"size" short:nil
                                            default:[NXNumber numberWithUnsignedInt32:0]],
                       [NXArgument argumentWithName:@"offset" short:nil
                                            default:[NXNumber numberWithInt32:0]],
                       nil];
#if !defined(SYSTEM_NAME_PICO)
  NXStream *zeroUsage = [NXStream streamWithCapacity:256];
  test_assert([[NXEnvironment environmentWithArgc:0 argv:NULL] writeUsageToStream:zeroUsage
                                                                            flags:zeros]);
  test_assert([zeroUsage seek:0 relative:NO]);
  test_assert([[zeroUsage readStringWithLength:256]
      isEqual:@"  --rate <float> (default: 0)\n"
              @"  --size <uint> (default: 0)\n"
              @"  --offset <int> (default: 0)\n"]);
  {
    static char *argv[] = {"prog", "--rate=1.5", "--offset=-2", NULL};
    NXEnvironment *zeroEnvironment = [NXEnvironment environmentWithArgc:3 argv:argv];
    NXMap *zeroValues = [zeroEnvironment parseFlags:zeros error:&error];
    test_assert(zeroValues != nil && error == nil);
    test_assert([[zeroValues objectForKey:@"rate"] float64Value] == 1.5);
    test_assert([[zeroValues objectForKey:@"offset"] int64Value] == -2);
    static char *negative[] = {"prog", "--size=-1", NULL};
    zeroEnvironment = [NXEnvironment environmentWithArgc:2 argv:negative];
    test_assert([zeroEnvironment parseFlags:zeros error:&error] == nil && error != nil);
  }
#else
  (void)zeros;
#endif

  NXArgument *flag = [NXArgument argumentWithName:@"count" short:@"n"];
  test_assert([[flag name] isEqual:@"count"] && [[flag shortName] isEqual:@"n"]);

  // Nothing after the program's name: every default
  NXMap *values = parse([NXArray arrayWithObjects:@"prog", nil], &environment, &error);
  test_assert(values != nil && error == nil);
  test_assert([values count] == 8);
  test_assert(![[values objectForKey:@"verbose"] boolValue]);
  test_assert([[values objectForKey:@"color"] boolValue]);
  test_assert([[values objectForKey:@"count"] int32Value] == 3);
  test_assert([[values objectForKey:@"label"] isEqual:@"none"]);
  test_assert([[values objectForKey:@"every"] int64Value] == NXSecond);
  test_assert([[values objectForKey:@"when"] isEqual:[NXDate dateWithYear:2026 month:1 day:1]]);
  test_assert([[environment arguments] count] == 0);

  // The environment
  test_assert([environment name] != nil && [environment system] != nil);

#if !defined(SYSTEM_NAME_PICO)
  // Every type given, and positional arguments
  values = parse([NXArray arrayWithObjects:@"prog", @"-v", @"-n", @"5", @"--big=7",
                                           @"--rate", @"1.5", @"--label=abc",
                                           @"--when", @"2026-09-06T11:37:05Z",
                                           @"--every", @"1h30m", @"one", @"two", nil],
                 &environment, &error);
  test_assert(values != nil && error == nil);
  test_assert([[values objectForKey:@"verbose"] boolValue]);
  test_assert([[values objectForKey:@"color"] boolValue]); // not given
  test_assert([[values objectForKey:@"count"] int64Value] == 5);
  test_assert([[values objectForKey:@"big"] unsignedInt64Value] == 7);
  test_assert([[values objectForKey:@"rate"] float64Value] == 1.5);
  test_assert([[values objectForKey:@"label"] isEqual:@"abc"]);
  test_assert([[values objectForKey:@"when"] seconds] == 1788694625);
  test_assert([[values objectForKey:@"every"] int64Value] == 90 * NXMinute);
  test_assert([[environment arguments] count] == 2);
  test_assert([[[environment arguments] objectAtIndex:0] isEqual:@"one"]);
  test_assert([[[environment arguments] objectAtIndex:1] isEqual:@"two"]);

  // An unknown flag, and a value of the wrong type, say why
  values = parse([NXArray arrayWithObjects:@"prog", @"--nope", @"one", nil], &environment,
                 &error);
  test_assert(values == nil && error != nil && [error containsString:@"nope"]);
  test_assert([[environment arguments] count] == 0);
  values = parse([NXArray arrayWithObjects:@"prog", @"--count", @"abc", nil], &environment,
                 &error);
  test_assert(values == nil && error != nil && [error containsString:@"count"]);
  values = parse([NXArray arrayWithObjects:@"prog", @"--when", @"yesterday", nil], &environment,
                 &error);
  test_assert(values == nil && error != nil);
  values = parse([NXArray arrayWithObjects:@"prog", @"--every", @"soon", nil], &environment,
                 &error);
  test_assert(values == nil && error != nil);

  // Without an error to set
  test_assert([environment parseFlags:flags() error:NULL] == nil);
#endif

  // Usage, with each flag's type and default, which works without a parse. There's none
  // on a Pico, which has no command line.
  environment = [NXEnvironment environmentWithArgc:0 argv:NULL];
  NXStream *stream = [NXStream streamWithCapacity:1024];
#if defined(SYSTEM_NAME_PICO)
  test_assert(![environment writeUsageToStream:stream flags:flags()]);
#else
  test_assert([environment writeUsageToStream:stream flags:flags()]);
  test_assert([stream seek:0 relative:NO]);
  NXString *usage = [stream readStringWithLength:1024];
  test_assert([usage isEqual:@"  --verbose, -v <bool> (default: false)\n"
                             @"  --color <bool> (default: true, negate: --no-color)\n"
                             @"  --count, -n <int> (default: 3)\n"
                             @"  --big <uint> (default: 1)\n"
                             @"  --rate <float> (default: 0.5)\n"
                             @"  --label, -l <string> (default: none)\n"
                             @"  --when <date> (default: 2026-01-01T00:00:00Z)\n"
                             @"  --every <duration> (default: 1s)\n"]);
#endif
  test_assert(![environment writeUsageToStream:nil flags:flags()]);
  test_assert(![environment writeUsageToStream:stream
                                         flags:[NXArray arrayWithObjects:@"x", nil]]);

  // Flags which aren't arguments, or are given twice
  environment = [NXEnvironment environmentWithArgc:0 argv:NULL];
  test_assert([environment parseFlags:[NXArray arrayWithObjects:@"x", nil] error:&error] == nil);
  test_assert(error != nil);
  NXArray *twice = [NXArray arrayWithObjects:[NXArgument argumentWithName:@"x" short:nil],
                                             [NXArgument argumentWithName:@"x" short:nil], nil];
  test_assert([environment parseFlags:twice error:&error] == nil && error != nil);

  // A short name which is another flag's, short or long, as picofuse finds either
  NXArray *shorts = [NXArray arrayWithObjects:[NXArgument argumentWithName:@"one" short:@"v"],
                                              [NXArgument argumentWithName:@"two" short:@"v"], nil];
  test_assert([environment parseFlags:shorts error:&error] == nil &&
              [error containsString:@"\"v\""]);
  NXArray *crossed = [NXArray
      arrayWithObjects:[NXArgument argumentWithName:@"foo" short:@"b"
                                            default:[NXNumber numberWithInt32:1]],
                       [NXArgument argumentWithName:@"b" short:nil
                                            default:[NXNumber numberWithInt32:2]],
                       nil];
  test_assert([environment parseFlags:crossed error:&error] == nil &&
              [error containsString:@"\"b\""]);
  test_assert(![environment writeUsageToStream:[NXStream streamWithCapacity:64] flags:crossed]);
  // Its own long name as its short name is just the one flag
  NXArray *own = [NXArray arrayWithObjects:[NXArgument argumentWithName:@"x" short:@"x"], nil];
  test_assert([environment parseFlags:own error:&error] != nil && error == nil);
  values = [environment parseFlags:nil error:&error];
  test_assert(values != nil && [values count] == 0 && error == nil);

  [pool release];
}
