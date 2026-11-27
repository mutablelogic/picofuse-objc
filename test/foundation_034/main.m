// Using arrays and maps in ways which mustn't be taken for misuse across threads
#include <Foundation/Foundation.h>
#include <test/test.h>

#if defined(SYSTEM_NAME_PICO)
#define WORKERS 1
#else
#define WORKERS 4
#endif
#define TIMES 2000

static NXArray *array;
static NXMap *map;
static NXLock *lock;
static NXWaitGroup *group;

// Compares by reading the array, which is being sorted by the same thread
@interface Reader : NXObject {
@public
  int value;
}
@end

@implementation Reader
- (NXComparisonResult)compare:(Reader *)other {
  test_assert([array count] > 0 && [array objectAtIndex:0] != nil);
  return value < other->value ? NXComparisonAscending
         : value > other->value ? NXComparisonDescending
                                : NXComparisonSame;
}
- (uintptr_t)hash {
  test_assert([map count] < 100);
  return (uintptr_t)value;
}
- (BOOL)isEqual:(id)other {
  return object_isKindOfClass(other, [Reader class]) && ((Reader *)other)->value == value;
}
- (id)copy {
  [map objectForKey:@"x"];
  return [self retain];
}
@end

// When it's deallocated, uses the collections it was removed from
@interface Leaver : NXObject
@end

@implementation Leaver
- (void)dealloc {
  [array appendObject:@"after"];
  [map setObject:@"after" forKey:@"after"];
  [super dealloc];
}
@end

static Reader *reader(int value) {
  Reader *r = [[[Reader alloc] init] autorelease];
  r->value = value;
  return r;
}

// Threads which share the collections under a lock
@interface Worker : NXObject
@end

@implementation Worker
+ (void)work {
  for (int i = 0; i < TIMES; i++) {
    [lock lock];
    [array appendObject:@"w"];
    [map setObject:@"w" forKey:[NXNumber numberWithInt32:i]];
    [array removeObjectAtIndex:0];
    [lock unlock];
  }
  [group done];
}
@end

static void start(SEL selector) {
  for (int tries = 0; ![NXThread run:selector target:[Worker class]]; tries++) {
    test_assert(tries < 1000);
    [NXThread sleepForDuration:NXMillisecond];
  }
}

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];

  // A comparator which reads the array it's sorting
  array = [NXArray arrayWithObjects:reader(3), reader(1), reader(2), nil];
  test_assert([array sortUsingSelector:@selector(compare:)]);
  test_assert(((Reader *)[array objectAtIndex:0])->value == 1);

  // A key whose hash and copy read the map it's being added to
  map = [NXMap map];
  test_assert([map setObject:@"a" forKey:reader(1)]);
  test_assert([map setObject:@"b" forKey:reader(1)]);
  test_assert([map removeObjectForKey:reader(1)]);

  // A removed object whose dealloc changes the collections
  Leaver *leaver = [[Leaver alloc] init];
  test_assert([array appendObject:leaver]);
  test_assert([map setObject:leaver forKey:@"leaver"]);
  [leaver release];
  test_assert([map removeObjectForKey:@"leaver"]);
  test_assert([array removeObject:leaver] == 1);
  test_assert([[array lastObject] isEqual:@"after"]);
  test_assert([[map objectForKey:@"after"] isEqual:@"after"]);
  [map removeAllObjects];
  [array removeAllObjects];

  // Strings and data which are appended to themselves, and formatted with themselves
  NXMutableString *string = [NXMutableString stringWithCString:"ab"];
  test_assert([string appendString:string]);
  test_assert([string appendFormat:@"%@-%@", string, string]);
  test_assert_strequal([string cStr], "abababab-abab");
  test_assert([string trimPrefix:[NXMutableString stringWithCString:"ab"]]);
  NXData *data = [NXData dataWithBytes:"xy" length:2];
  test_assert([data appendData:data] && [data length] == 4);
  test_assert([data appendBytes:[data bytes] length:[data length]] && [data length] == 8);

  // Threads which take turns with a lock
  lock = [[NXLock alloc] init];
  group = [[NXWaitGroup alloc] init];
  test_assert([array appendObject:@"first"]);
  [group add:WORKERS];
  for (int i = 0; i < WORKERS; i++) {
    start(@selector(work));
  }
  for (int i = 0; i < TIMES; i++) {
    [lock lock];
    test_assert([array count] == 1);
    for (id object in array) {
      (void)object;
    }
    (void)[map count];
    [lock unlock];
  }
  [group wait];
  test_assert([array count] == 1 && [map count] == TIMES);
  [group release];
  [lock release];
  [pool release];
}
