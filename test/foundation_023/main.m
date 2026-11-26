#include <Foundation/Foundation.h>
#include <test/test.h>

// An object which counts how many there are
static int alive = 0;

@interface Counted : NXObject {
@private
  int _value;
}
+ (id)counted:(int)value;
- (int)value;
@end

@implementation Counted
+ (id)counted:(int)value {
  Counted *counted = [[[self alloc] init] autorelease];
  counted->_value = value;
  alive++;
  return counted;
}
- (void)dealloc {
  alive--;
  [super dealloc];
}
- (int)value {
  return _value;
}
- (BOOL)isEqual:(id)anObject {
  return object_isKindOfClass(anObject, [Counted class]) &&
         ((Counted *)anObject)->_value == _value;
}
- (NXString *)description {
  return [NXString stringWithFormat:@"c%d", _value];
}
@end

// An object which empties an array when it's deallocated
static NXArray *emptied = nil;

@interface Emptier : NXObject
@end

@implementation Emptier
- (void)dealloc {
  [emptied removeAllObjects];
  [super dealloc];
}
@end

// Objects whose dealloc changes the array they're being removed from
static void reentrant(void) {
  emptied = [[NXArray alloc] init];
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  Emptier *emptier = [[Emptier alloc] init];
  test_assert([emptied appendObject:emptier] && [emptied appendObject:@"a"]);
  [emptier release];
  test_assert([emptied replaceObjectAtIndex:0 withObject:@"b"]);
  test_assert([emptied count] == 0);

  emptier = [[Emptier alloc] init];
  test_assert([emptied appendObject:@"a"] && [emptied appendObject:emptier]);
  [emptier release];
  test_assert([emptied removeObjectAtIndex:1] && [emptied count] == 0);

  emptier = [[Emptier alloc] init];
  test_assert([emptied appendObject:emptier] && [emptied appendObject:@"a"]);
  [emptier release];
  [emptied removeAllObjects];
  test_assert([emptied count] == 0);
  [pool release];
  [emptied release];
  emptied = nil;
}

static void arrays(NXZone *zone) {
  // Empty
  NXArray *array = [NXArray array];
  test_assert(array != nil && [array zone] == zone);
  test_assert([array count] == 0 && [array capacity] == 0);
  test_assert([array objectAtIndex:0] == nil);
  test_assert([array firstObject] == nil && [array lastObject] == nil);
  test_assert(![array removeLastObject] && ![array removeObjectAtIndex:0]);
  test_assert([array indexOfObject:@"x"] == NXNotFound);
  test_assert_strequal([[array description] cStr], "[]");

  // Adding, which makes room
  test_assert([array appendObject:@"a"] && [array capacity] == 4);
  test_assert([array appendObject:@"c"] && [array insertObject:@"b" atIndex:1]);
  test_assert([array insertObject:@"0" atIndex:0]);
  test_assert([array appendObject:@"d"] && [array capacity] == 8);
  test_assert([array count] == 5);
  test_assert_strequal([[array description] cStr], "[0, a, b, c, d]");
  test_assert([[array firstObject] isEqual:@"0"] && [[array lastObject] isEqual:@"d"]);
  test_assert(![array appendObject:nil]);
  test_assert(![array insertObject:@"x" atIndex:6]);
  test_assert([array insertObject:@"e" atIndex:5] && [array count] == 6);

  // Finding, by isEqual:
  test_assert([array indexOfObject:[NXString stringWithCString:"b"]] == 2);
  test_assert([array containsObject:@"e"] && ![array containsObject:@"z"]);
  test_assert(![array containsObject:nil]);

  // Replacing and removing
  test_assert([array replaceObjectAtIndex:0 withObject:@"z"]);
  test_assert(![array replaceObjectAtIndex:6 withObject:@"z"]);
  test_assert(![array replaceObjectAtIndex:0 withObject:nil]);
  test_assert([array appendObject:@"z"] && [array removeObject:@"z"] == 2);
  test_assert([array removeObject:@"z"] == 0 && [array removeObject:nil] == 0);
  test_assert([array removeObjectAtIndex:1] && [array removeLastObject]);
  test_assert_strequal([[array description] cStr], "[a, c, d]");
  size_t capacity = [array capacity];
  [array removeAllObjects];
  test_assert([array count] == 0 && [array capacity] == capacity);

  // With objects, and capacity
  array = [NXArray arrayWithObjects:@"x", [NXNumber numberWithInt32:2],
                                    [NXNull nullValue], nil];
  test_assert(array != nil);
  test_assert([array count] == 3);
  test_assert_strequal([[array description] cStr], "[x, 2, null]");
  test_assert([[NXArray arrayWithObjects:nil] count] == 0);
  array = [NXArray arrayWithCapacity:100];
  test_assert([array capacity] == 100 && [array count] == 0);
  test_assert([NXArray arrayWithCapacity:SIZE_MAX] == nil);

  // Equal
  NXArray *ab = [NXArray arrayWithObjects:@"a", @"b", nil];
  NXArray *ab2 = [NXArray arrayWithObjects:[NXString stringWithCString:"a"], @"b", nil];
  NXArray *ba = [NXArray arrayWithObjects:@"b", @"a", nil];
  NXArray *a1 = [NXArray arrayWithObjects:@"a", nil];
  NXArray *aa = [NXArray arrayWithObjects:@"a", @"a", nil];
  test_assert([ab isEqual:ab2] && ![ab isEqual:ba] && ![a1 isEqual:aa]);
  test_assert([[NXArray array] isEqual:[NXArray array]]);
  test_assert(![[NXArray array] isEqual:@"[]"] && ![[NXArray array] isEqual:nil]);

  // An array in an array
  NXArray *inner = [NXArray arrayWithObjects:@"i", nil];
  NXArray *outer = [NXArray arrayWithObjects:inner, @"o", nil];
  test_assert_strequal([[outer description] cStr], "[[i], o]");
}

// The objects are retained, and released when they're removed
static void retaining(void) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  NXArray *array = [[NXArray alloc] init];
  for (int i = 0; i < 10; i++) {
    test_assert([array appendObject:[Counted counted:i]]);
  }
  [pool drain];
  test_assert(alive == 10 && [[array objectAtIndex:3] value] == 3);

  test_assert([array removeObjectAtIndex:3] && alive == 9);
  test_assert([array removeObject:[Counted counted:5]] == 1);
  [pool drain];
  test_assert(alive == 8);
  test_assert([array replaceObjectAtIndex:0 withObject:[Counted counted:100]]);
  [pool drain];
  test_assert(alive == 8);

  // The same object in its own place, and twice
  test_assert([array replaceObjectAtIndex:1 withObject:[array objectAtIndex:1]]);
  test_assert([array appendObject:[array objectAtIndex:1]] && alive == 8);
  test_assert([array removeObject:[array objectAtIndex:1]] == 2 && alive == 7);
  test_assert([array removeLastObject] && alive == 6);
  [array removeAllObjects];
  test_assert(alive == 0);

  // And when it's deallocated
  for (int i = 0; i < 5; i++) {
    test_assert([array appendObject:[Counted counted:i]]);
  }
  [pool drain];
  test_assert(alive == 5);
  [array release];
  test_assert(alive == 0);
  [pool release];
}

// Many, so that the memory is moved, in a zone and not
static void growing(NXZone *zone) {
  NXArray *array = [NXArray array];
  for (int i = 0; i < 2000; i++) {
    test_assert([array appendObject:[NXNumber numberWithInt32:i]]);
  }
  test_assert([array count] == 2000 && [array capacity] == 2048);
  for (int i = 0; i < 2000; i++) {
    test_assert([[array objectAtIndex:i] int32Value] == i);
  }
  if (zone != nil) {
    test_assert([zone count] > 2000);
  }
}

test_main(0) {
  for (int i = 0; i < 3; i++) {
    NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
    arrays(nil);
    growing(nil);
    [pool release];
  }
  retaining();
  test_assert(alive == 0);
  reentrant();

  // In a zone, where an arena is too small for all of it
  NXZone *zone = [NXZone zoneWithSize:4096];
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  arrays(zone);
  growing(zone);
  [pool release];
  test_assert([zone count] == 0);
  [zone release];
}
