// for...in loops over arrays and maps
#include <Foundation/Foundation.h>
#include <test/test.h>

// Goes through any collection, counting its objects
static size_t count_in(id<NXCollection> collection) {
  size_t n = 0;
  for (id object in collection) {
    test_assert(object != nil);
    n++;
  }
  return n;
}

static void arrays(void) {
  // Empty, with and without room
  test_assert(count_in([NXArray array]) == 0);
  test_assert(count_in([NXArray arrayWithCapacity:8]) == 0);

  // In order, more than a batch of 16
  NXArray *array = [NXArray array];
  for (int64_t i = 0; i < 40; i++) {
    test_assert([array appendObject:[NXNumber numberWithInt64:i]]);
  }
  int64_t next = 0;
  for (NXNumber *number in array) {
    test_assert([number int64Value] == next);
    next++;
  }
  test_assert(next == 40);
  test_assert(count_in(array) == 40);

  // Stopping early, and loops inside loops
  size_t n = 0;
  for (NXNumber *number in array) {
    if ([number int64Value] == 10) {
      break;
    }
    n++;
  }
  test_assert(n == 10);
  n = 0;
  for (id a in array) {
    for (id b in array) {
      (void)a, (void)b;
      n++;
    }
  }
  test_assert(n == 40 * 40);

  // Replacing objects in place is allowed, and the loop sees each as it is then
  size_t index = 0;
  for (NXNumber *number in array) {
    test_assert([array replaceObjectAtIndex:index
                                 withObject:[NXNumber numberWithInt64:-[number int64Value]]]);
    index++;
  }
  next = 0;
  for (NXNumber *number in array) {
    test_assert([number int64Value] == -next);
    next++;
  }

  // As is removing one, then stopping
  for (id object in array) {
    test_assert([array removeObject:object] == 1);
    break;
  }
  test_assert([array count] == 39);

  // A loop after changes sees them
  test_assert([array appendObject:@"last"]);
  test_assert(count_in(array) == 40);
}

static void maps(void) {
  // Empty, with and without a table
  NXMap *map = [NXMap map];
  test_assert(count_in(map) == 0);
  test_assert([map setObject:@"a" forKey:@"a"] && [map removeObjectForKey:@"a"]);
  test_assert(count_in(map) == 0);

  // Every key once, more than a batch of 16
  for (int64_t i = 0; i < 40; i++) {
    test_assert([map setObject:[NXNumber numberWithInt64:i * 2]
                        forKey:[NXNumber numberWithInt64:i]]);
  }
  NXMap *seen = [NXMap map];
  for (NXNumber *key in map) {
    test_assert([seen objectForKey:key] == nil);
    test_assert([seen setObject:key forKey:key]);
    NXNumber *object = [map objectForKey:key];
    test_assert([object int64Value] == [key int64Value] * 2);
  }
  test_assert([seen count] == 40);

  // Setting the object for a key which is there is allowed
  for (NXNumber *key in map) {
    test_assert([map setObject:@"changed" forKey:key]);
  }
  for (NXNumber *key in map) {
    test_assert([[map objectForKey:key] isEqual:@"changed"]);
  }

  // As is removing a key, then stopping
  for (NXNumber *key in map) {
    test_assert([map removeObjectForKey:key]);
    break;
  }
  test_assert([map count] == 39 && count_in(map) == 39);

  // And it keeps working as the map grows
  for (int64_t i = 100; i < 200; i++) {
    test_assert([map setObject:@"x" forKey:[NXNumber numberWithInt64:i]]);
  }
  test_assert(count_in(map) == 139);
}

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  arrays();
  maps();
  [pool release];
}
