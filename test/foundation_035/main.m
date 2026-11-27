// Misusing an array or map across threads panics. One case for each program.
#include <Foundation/Foundation.h>
#include <test/test.h>

static NXArray *array;
static NXMap *map;
static NXAtomic *inside; // set when the other thread is in the middle of a change

// Signals that the change has started, and then waits for ever, or changes the
// collection itself, when it's compared or its key is copied
@interface Blocker : NXObject {
@public
  BOOL nested;
}
@end

@implementation Blocker
- (void)changing {
  if (nested) {
    [array appendObject:@"nested"];
    [map removeObjectForKey:@"other"];
  }
  [inside setUnsignedInt32Value:1];
  for (;;) {
    [NXThread sleepForDuration:NXMillisecond];
  }
}
- (NXComparisonResult)compare:(id)other {
  (void)other;
  [self changing];
  return NXComparisonSame;
}
- (uintptr_t)hash {
  return 0;
}
- (BOOL)isEqual:(id)other {
  return other == self;
}
- (id)copy {
  [self changing];
  return [self retain];
}
@end

// Marks a string or data as being changed by the calling thread, as if it were in the
// middle of a change, which is how another thread's change is held open
void NXChangeBegin(uintptr_t *changing, const char *method);

@interface NXMutableString (Test)
- (void)markChangedByThisThread;
@end

@interface NXData (Test)
- (void)markChangedByThisThread;
@end

@implementation NXMutableString (Test)
- (void)markChangedByThisThread {
  NXChangeBegin(&_changing, "test");
}
@end

@implementation NXData (Test)
- (void)markChangedByThisThread {
  NXChangeBegin(&_changing, "test");
}
@end

static NXMutableString *string;
static NXData *data;

@interface Worker : NXObject
@end

@implementation Worker
+ (void)sort {
  [array sortUsingSelector:@selector(compare:)];
}
+ (void)markString {
  [string markChangedByThisThread];
  [inside setUnsignedInt32Value:1];
}
+ (void)markData {
  [data markChangedByThisThread];
  [inside setUnsignedInt32Value:1];
}
+ (void)set {
  Blocker *key = [[Blocker alloc] init];
  [map setObject:@"x" forKey:key];
}
@end

// Runs a change in another thread, and waits until it's in the middle of it
__attribute__((unused)) static void change_in_thread(SEL selector) {
  test_assert([NXThread run:selector target:[Worker class]]);
  while ([inside unsignedInt32Value] == 0) {
    [NXThread sleepForDuration:NXMillisecond];
  }
}

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  inside = [[NXAtomic alloc] init];
  array = [[NXArray alloc] init];
  map = [[NXMap alloc] init];
  Blocker *a = [[Blocker alloc] init], *b = [[Blocker alloc] init];
  test_assert([array appendObject:a] && [array appendObject:b]);
  test_assert([map setObject:@"y" forKey:@"other"]);

#if defined(CASE_array_two_threads)
  change_in_thread(@selector(sort));
  [array appendObject:@"z"];
#elif defined(CASE_array_read)
  change_in_thread(@selector(sort));
  (void)[array count];
#elif defined(CASE_array_nested)
  a->nested = YES;
  b->nested = YES;
  [array sortUsingSelector:@selector(compare:)];
#elif defined(CASE_string_two_threads)
  string = [[NXMutableString alloc] init];
  change_in_thread(@selector(markString));
  [string appendCString:"z"];
#elif defined(CASE_string_read)
  string = [[NXMutableString alloc] init];
  change_in_thread(@selector(markString));
  (void)[string length];
#elif defined(CASE_data_two_threads)
  data = [[NXData alloc] init];
  change_in_thread(@selector(markData));
  [data appendBytes:"z" length:1];
#elif defined(CASE_data_read)
  data = [[NXData alloc] init];
  change_in_thread(@selector(markData));
  (void)[data length];
#elif defined(CASE_array_equal_other)
  change_in_thread(@selector(sort));
  (void)[[NXArray array] isEqual:array];
#elif defined(CASE_map_equal_other)
  change_in_thread(@selector(set));
  (void)[[NXMap map] isEqual:map];
#elif defined(CASE_map_remove_all)
  change_in_thread(@selector(set));
  [map removeAllObjects];
#elif defined(CASE_map_two_threads)
  change_in_thread(@selector(set));
  [map setObject:@"z" forKey:@"z"];
#elif defined(CASE_map_read)
  change_in_thread(@selector(set));
  (void)[map objectForKey:@"other"];
#elif defined(CASE_map_nested)
  Blocker *key = [[Blocker alloc] init];
  key->nested = YES;
  [array release];
  array = nil;
  [map setObject:@"x" forKey:key];
#endif
  [pool release];
  test_assert(!"it should have panicked");
}
