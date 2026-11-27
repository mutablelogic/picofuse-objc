// +new, maps from arrays of objects and keys, and data from strings
#include <Foundation/Foundation.h>
#include <string.h>
#include <test/test.h>

@interface Counter : NXObject {
@public
  int value;
}
@end

@implementation Counter
- (id)init {
  self = [super init];
  if (self != nil) {
    value = 42;
  }
  return self;
}
@end

test_main(0) {
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];

  // +new is alloc and init, and isn't autoreleased: if it were, releasing it here would
  // panic when the pool is drained
  Counter *counter = [Counter new];
  test_assert(counter != nil && counter->value == 42);
  [counter release];
  NXArray *array = [NXArray new];
  test_assert(array != nil && [array count] == 0 && [array appendObject:@"a"]);
  [array release];

  // A map from two arrays
  NXArray *objects = [NXArray arrayWithObjects:@"one", @"two", @"three", nil];
  NXArray *keys = [NXArray arrayWithObjects:@"a", [NXNumber numberWithInt32:2], @"c", nil];
  NXMap *map = [NXMap mapWithObjects:objects forKeys:keys];
  test_assert(map != nil && [map count] == 3);
  test_assert([[map objectForKey:@"a"] isEqual:@"one"]);
  test_assert([[map objectForKey:[NXNumber numberWithInt32:2]] isEqual:@"two"]);
  test_assert([[map objectForKey:@"c"] isEqual:@"three"]);

  // The last object for a key which is there twice, and none if they're empty
  map = [NXMap mapWithObjects:[NXArray arrayWithObjects:@"x", @"y", nil]
                      forKeys:[NXArray arrayWithObjects:@"k", @"k", nil]];
  test_assert([map count] == 1 && [[map objectForKey:@"k"] isEqual:@"y"]);
  test_assert([[NXMap mapWithObjects:[NXArray array] forKeys:[NXArray array]] count] == 0);
  test_assert([[NXMap mapWithObjects:nil forKeys:nil] count] == 0);

  // Arrays of different counts
  test_assert([NXMap mapWithObjects:objects forKeys:[NXArray arrayWithObjects:@"a", nil]] ==
              nil);
  test_assert([NXMap mapWithObjects:nil forKeys:keys] == nil);

  // Data from a string's UTF-8, without a terminating zero
  NXData *data = [NXData dataWithString:@"caf\xC3\xA9"];
  test_assert(data != nil && [data length] == 5);
  test_assert(memcmp([data bytes], "caf\xC3\xA9", 5) == 0);
  test_assert([[NXData dataWithString:@""] length] == 0);
  test_assert([[NXData dataWithString:nil] length] == 0);
  NXMutableString *string = [NXMutableString stringWithCString:"abc"];
  data = [NXData dataWithString:string];
  test_assert([string appendCString:"d"] && [data length] == 3); // a copy

  [pool release];
}
