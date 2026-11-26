#include <Foundation/Foundation.h>
#include <test/test.h>

// An object which counts how many there are
static int alive = 0;

@interface Counted : NXObject
+ (id)counted;
@end

@implementation Counted
+ (id)counted {
  alive++;
  return [[[self alloc] init] autorelease];
}
- (void)dealloc {
  alive--;
  [super dealloc];
}
@end

// Keys which all have the same hash, so that they're next to each other in a map
@interface Collider : NXObject {
@private
  int _value;
}
+ (id)collider:(int)value;
@end

@implementation Collider
+ (id)collider:(int)value {
  Collider *collider = [[[self alloc] init] autorelease];
  collider->_value = value;
  return collider;
}
- (uintptr_t)hash {
  return 42;
}
- (BOOL)isEqual:(id)anObject {
  return object_isKindOfClass(anObject, [Collider class]) &&
         ((Collider *)anObject)->_value == _value;
}
@end

// An object which removes a key from a map when it's deallocated, which moves the keys
// after it
static NXMap *changed = nil;

@interface Remover : NXObject
@end

@implementation Remover
- (void)dealloc {
  [changed removeObjectForKey:[Collider collider:1]];
  [super dealloc];
}
@end

static void maps(NXZone *zone) {
  // Empty
  NXMap *map = [NXMap map];
  test_assert(map != nil && [map zone] == zone && [map count] == 0);
  test_assert([map objectForKey:@"a"] == nil && ![map containsObject:@"a"]);
  test_assert(![map removeObjectForKey:@"a"] && [map objectForKey:nil] == nil);
  test_assert([[map allKeys] count] == 0 && [[map allObjects] count] == 0);
  test_assert_strequal([[map description] cStr], "{}");

  // Setting, finding and replacing
  test_assert([map setObject:@"1" forKey:@"a"] && [map setObject:@"2" forKey:@"b"]);
  test_assert([map count] == 2 && [[map objectForKey:@"a"] isEqual:@"1"]);
  test_assert([[map objectForKey:[NXString stringWithCString:"b"]] isEqual:@"2"]);
  test_assert([map containsObject:@"a"] && ![map containsObject:@"1"]);
  test_assert([map setObject:@"3" forKey:@"a"] && [map count] == 2);
  test_assert([[map objectForKey:@"a"] isEqual:@"3"]);
  test_assert(![map setObject:nil forKey:@"c"] && ![map setObject:@"x" forKey:nil]);

  // Keys are equal if they're equal, whatever their type
  test_assert([map setObject:@"one" forKey:[NXNumber numberWithInt32:1]]);
  test_assert([[map objectForKey:[NXNumber numberWithFloat64:1.0]] isEqual:@"one"]);
  test_assert([[map objectForKey:[NXNumber trueValue]] isEqual:@"one"]);
  test_assert([map setObject:@"uno" forKey:[NXNumber numberWithUnsignedInt64:1]]);
  test_assert([map count] == 3);

  // Removing
  test_assert([map removeObjectForKey:@"a"] && [map count] == 2);
  test_assert([map objectForKey:@"a"] == nil && ![map removeObjectForKey:@"a"]);
  [map removeAllObjects];
  test_assert([map count] == 0 && [map objectForKey:@"b"] == nil);

  // A key is copied, so changing it afterwards doesn't change the map
  NXMutableString *key = [NXMutableString stringWithCString:"key"];
  test_assert([map setObject:@"value" forKey:key]);
  test_assert([key appendCString:"!"]);
  test_assert([[map objectForKey:@"key"] isEqual:@"value"]);
  test_assert([map objectForKey:@"key!"] == nil);
  test_assert([[map allKeys] objectAtIndex:0] != key);
  test_assert(!object_isKindOfClass([[map allKeys] objectAtIndex:0],
                                    [NXMutableString class]));

  // With keys and objects
  map = [NXMap mapWithKeysAndObjects:@"a", [NXNumber numberWithInt32:1], @"b",
                                     [NXNull nullValue], nil];
  test_assert([map count] == 2 && [[map objectForKey:@"b"] isEqual:[NXNull nullValue]]);
  NXString *description = [map description];
  test_assert([description isEqual:@"{a: 1, b: null}"] ||
              [description isEqual:@"{b: null, a: 1}"]);
  NXArray *keys = [map allKeys];
  NXArray *objects = [map allObjects];
  test_assert([keys count] == 2 && [objects count] == 2);
  for (size_t i = 0; i < 2; i++) {
    test_assert([[map objectForKey:[keys objectAtIndex:i]]
        isEqual:[objects objectAtIndex:i]]);
  }
  test_assert([[NXMap mapWithKeysAndObjects:nil] count] == 0);
  test_assert([NXMap mapWithCapacity:SIZE_MAX] == nil);

  // Equal, hashes and copies
  NXMap *same = [NXMap mapWithKeysAndObjects:@"b", [NXNull nullValue], @"a",
                                             [NXNumber numberWithFloat64:1.0], nil];
  test_assert([map isEqual:same] && [same isEqual:map] && [map hash] == [same hash]);
  test_assert(![map isEqual:[NXMap map]] && ![map isEqual:nil] && ![map isEqual:@"{}"]);
  test_assert(![map isEqual:[NXMap mapWithKeysAndObjects:@"a", @"1", @"b", @"2", nil]]);
  NXMap *copy = [map copy];
  test_assert(copy != map && [copy zone] == zone && [copy isEqual:map]);
  test_assert([copy setObject:@"c" forKey:@"c"] && [map count] == 2);
  [copy release];
  test_assert([[NXMap map] isEqual:[NXMap map]]);
}

// Many keys, so the table grows and keys collide, and half are removed
static void many(NXZone *zone) {
  NXMap *map = [NXMap map];
  for (int i = 0; i < 500; i++) {
    test_assert([map setObject:[NXNumber numberWithInt32:i * i]
                        forKey:[NXString stringWithFormat:@"k%d", i]]);
  }
  test_assert([map count] == 500);
  for (int i = 0; i < 500; i += 2) {
    test_assert([map removeObjectForKey:[NXString stringWithFormat:@"k%d", i]]);
  }
  test_assert([map count] == 250);
  for (int i = 0; i < 500; i++) {
    id object = [map objectForKey:[NXString stringWithFormat:@"k%d", i]];
    test_assert(i % 2 == 0 ? object == nil : [object int32Value] == i * i);
  }

  // Numbers and objects as keys too
  NXMap *numbers = [NXMap mapWithCapacity:100];
  for (int i = 0; i < 500; i++) {
    test_assert([numbers setObject:@"x" forKey:[NXNumber numberWithInt32:i]]);
  }
  for (int i = 0; i < 500; i += 3) {
    test_assert([numbers removeObjectForKey:[NXNumber numberWithFloat64:i]]);
  }
  for (int i = 0; i < 500; i++) {
    test_assert([numbers containsObject:[NXNumber numberWithInt64:i]] == (i % 3 != 0));
  }
  test_assert([[numbers allKeys] count] == [numbers count]);
  (void)zone;
}

// Keys and objects are retained, and released when they're removed
static void retaining(void) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  NXMap *map = [[NXMap alloc] init];
  for (int i = 0; i < 20; i++) {
    test_assert([map setObject:[Counted counted]
                        forKey:[NXNumber numberWithInt32:i]]);
  }
  test_assert([map setObject:@"key" forKey:[Counted counted]]);
  [pool drain];
  test_assert(alive == 21);
  test_assert([map setObject:[Counted counted] forKey:[NXNumber numberWithInt32:0]]);
  [pool drain];
  test_assert(alive == 21);
  test_assert([map removeObjectForKey:[NXNumber numberWithInt32:1]]);
  test_assert(alive == 20);
  [map removeAllObjects];
  test_assert(alive == 0);
  for (int i = 0; i < 5; i++) {
    test_assert([map setObject:[Counted counted] forKey:[NXNumber numberWithInt32:i]]);
  }
  [pool drain];
  [map release];
  test_assert(alive == 0);

  // A dealloc which changes the map
  changed = [[NXMap alloc] init];
  for (int round = 0; round < 3; round++) {
    Remover *remover = [[Remover alloc] init];
    test_assert([changed setObject:@"x" forKey:[Collider collider:1]]);
    test_assert([changed setObject:remover forKey:[Collider collider:2]]);
    [remover release];
    if (round == 0) {
      test_assert([changed setObject:@"y" forKey:[Collider collider:2]]);
      test_assert([[changed objectForKey:[Collider collider:2]] isEqual:@"y"]);
      test_assert([changed count] == 1);
    } else if (round == 1) {
      test_assert([changed removeObjectForKey:[Collider collider:2]]);
    } else {
      [changed removeAllObjects];
    }
    test_assert([changed objectForKey:[Collider collider:1]] == nil);
    [changed removeAllObjects];
    [pool drain];
  }
  [changed release];
  changed = nil;
  [pool release];
}

test_main(0) {
  for (int i = 0; i < 3; i++) {
    NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
    maps(nil);
    [pool release];
  }
  NXAutoreleasePool *outer = [[NXAutoreleasePool alloc] init];
  many(nil);
  [outer release];
  retaining();
  test_assert(alive == 0);

  NXZone *zone = [NXZone zoneWithSize:4096];
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  maps(zone);
  many(zone);
  [pool release];
  test_assert([zone count] == 0);
  [zone release];
}
