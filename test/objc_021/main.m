#include <test/TestObject.h>
#include <test/test.h>

static int early(id object, int value) {
  (void)object; // GCC doesn't count @synchronized as using it
  @synchronized(object) {
    if (value < 0) {
      return -1;
    }
    for (int i = 0; i < 10; i++) {
      @synchronized([Object class]) {
        if (i == value) {
          break;
        }
        continue;
      }
    }
  }
  return value;
}

// Lock a different object at each level, and the first object at all of them
static int nest(TestObject **objects, int count) {
  if (count == 0) {
    return 0;
  }
  int result;
  @synchronized(objects[0]) {
    @synchronized(objects[count]) {
      result = 1 + nest(objects, count - 1);
    }
  }
  return result;
}

test_main(0) {
  TestObject *object = [[TestObject alloc] init];
  TestObject *other = [[TestObject alloc] init];

  // Unlocking what isn't locked is an error
  test_assert(objc_sync_exit(object) != 0);

  // The lock can be taken again by the thread which holds it
  test_assert(objc_sync_enter(object) == 0);
  test_assert(objc_sync_enter(object) == 0);
  test_assert(objc_sync_enter(other) == 0);
  test_assert(objc_sync_exit(object) == 0);
  test_assert(objc_sync_exit(object) == 0);
  test_assert(objc_sync_exit(object) != 0);
  test_assert(objc_sync_exit(other) == 0);
  test_assert(objc_sync_exit(other) != 0);

  // Nothing happens for nil
  test_assert(objc_sync_enter(nil) == 0);
  test_assert(objc_sync_exit(nil) == 0);
  int count = 0;
  @synchronized((id)nil) {
    count++;
  }
  test_assert(count == 1);

  // The lock is released however the block is left
  test_assert(early(object, -1) == -1);
  test_assert(early(object, 3) == 3);
  test_assert(objc_sync_exit(object) != 0);
  test_assert(objc_sync_exit((id)[Object class]) != 0);

  // As many objects can be locked at once as there is room for, and that can be
  // done again
  TestObject *objects[OBJC_SYNC_CAPACITY];
  for (int i = 0; i < OBJC_SYNC_CAPACITY; i++) {
    objects[i] = [[TestObject alloc] init];
    test_assert(objects[i] != nil);
  }
  for (int i = 0; i < 3; i++) {
    test_assert(nest(objects, OBJC_SYNC_CAPACITY - 1) ==
                OBJC_SYNC_CAPACITY - 1);
  }
  for (int i = 0; i < OBJC_SYNC_CAPACITY; i++) {
    test_assert(objc_sync_exit(objects[i]) != 0);
    [objects[i] free];
  }

  [other free];
  [object free];
}
