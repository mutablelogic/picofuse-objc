#include <Foundation/Foundation.h>
#include <stddef.h>
#include <test/test.h>

static int deallocated = 0;

@interface Thing : NXObject {
  int _values[8];
}
- (int)sum;
- (void)fill;
@end

@implementation Thing
- (int)sum {
  int total = 0;
  for (int i = 0; i < 8; i++) {
    total += _values[i];
  }
  return total;
}
- (void)fill {
  for (int i = 0; i < 8; i++) {
    _values[i] = -1;
  }
}
- (void)dealloc {
  deallocated++;
  [super dealloc];
}
@end

// Allocate, use and release some objects
static void objects(NXZone *zone) {
  deallocated = 0;

  Thing *thing = [[Thing alloc] init];
  test_assert(thing != nil);
  test_assert([thing zone] == zone);
  test_assert([thing class] == [Thing class]);
  test_assert([thing isKindOfClass:[NXObject class]]);
  test_assert((uintptr_t)thing % _Alignof(max_align_t) == 0);

  // It's deallocated when it's been released as often as it's been retained
  test_assert([thing retain] == thing);
  test_assert([[thing retain] retain] == thing);
  [thing release];
  [thing release];
  [thing release];
  test_assert(deallocated == 0);
  [thing release];
  test_assert(deallocated == 1);

  // Instance variables start as zero, even where memory is used again
  for (int i = 0; i < 20; i++) {
    Thing *again = [[Thing alloc] init];
    test_assert([again sum] == 0);
    [again fill];
    test_assert([again sum] == -8);
    [again release];
  }
  test_assert(deallocated == 21);

  // Nothing happens for nil
  Thing *none = nil;
  test_assert([none retain] == nil);
  [none release];
}

test_main(0) {
  // NXObject has no instance variables, as constant strings can't
  test_assert(class_getInstanceSize([NXObject class]) == sizeof(Class));

  // Without a default zone
  test_assert([NXZone defaultZone] == nil);
  objects(nil);

  // An object which wasn't allocated in a zone can outlive one
  Thing *before = [[Thing alloc] init];

  // With a default zone
  NXZone *zone = [NXZone zoneWithSize:1024];
  test_assert(zone != nil && [NXZone defaultZone] == zone);
  objects(zone);
  test_assert([zone count] == 0);
  [zone release];

  // Without one again
  test_assert([NXZone defaultZone] == nil);
  objects(nil);
  test_assert([before zone] == nil && [before sum] == 0);
  [before release];
}
