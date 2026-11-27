// Changing a collection in a for...in loop panics. One case for each program.
#include <Foundation/Foundation.h>
#include <test/test.h>

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  NXArray *array = [NXArray array];
  NXMap *map = [NXMap map];
  for (int64_t i = 0; i < 4; i++) {
    NXNumber *number = [NXNumber numberWithInt64:i];
    test_assert([array appendObject:number]);
    test_assert([map setObject:number forKey:number]);
  }

#if defined(CASE_array_append)
  for (id object in array) {
    [array appendObject:object];
  }
#elif defined(CASE_array_remove)
  for (id object in array) {
    [array removeObject:object];
  }
#elif defined(CASE_array_sort)
  for (id object in array) {
    (void)object;
    [array sortUsingSelector:@selector(compare:)];
  }
#elif defined(CASE_array_remove_only)
  // The only object, when the loop doesn't check again before it ends
  NXArray *one = [NXArray arrayWithObjects:@"a", nil];
  for (id object in one) {
    [one removeObject:object];
  }
#elif defined(CASE_map_add)
  int64_t i = 100;
  for (id key in map) {
    (void)key;
    [map setObject:@"x" forKey:[NXNumber numberWithInt64:i++]];
  }
#elif defined(CASE_map_remove_only)
  NXMap *one = [NXMap map];
  [one setObject:@"a" forKey:@"a"];
  for (id key in one) {
    [one removeObjectForKey:key];
  }
#elif defined(CASE_map_remove_rest)
  // Every key, in the last of the first batch
  size_t n = 0;
  for (id key in map) {
    (void)key;
    if (++n == [map count]) {
      [map removeAllObjects];
    }
  }
#elif defined(CASE_map_remove)
  for (id key in map) {
    [map removeObjectForKey:key];
  }
#endif
  [pool release];
  test_assert(!"the loop should have panicked");
}
