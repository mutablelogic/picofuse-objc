#include <Foundation/Foundation.h>
#include <test/test.h>

#define MANY 1000

static int deallocated = 0;
static int last = 0;

@interface Thing : NXObject {
@protected
  int _number;
}
+ (id)thing:(int)number;
- (int)number;
@end

@implementation Thing
+ (id)thing:(int)number {
  Thing *thing = [[self alloc] init];
  thing->_number = number;
  return [thing autorelease];
}
- (int)number {
  return _number;
}
- (void)dealloc {
  deallocated++;
  last = _number;
  [super dealloc];
}
@end

// Autoreleases others when it's deallocated
@interface Chain : Thing
@end

@implementation Chain
- (void)dealloc {
  if (_number > 0) {
    [Chain thing:_number - 1];
  }
  [super dealloc];
}
@end

static void pools(void) {
  deallocated = 0;
  test_assert([NXAutoreleasePool currentPool] == nil);

  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  test_assert(pool != nil && [NXAutoreleasePool currentPool] == pool);
  test_assert([pool count] == 0);

  // Objects are released when the pool is drained, last first, and it can be used
  // again
  for (int i = 0; i < 2; i++) {
    deallocated = 0;
    Thing *thing = [Thing thing:1];
    test_assert([thing number] == 1);
    [Thing thing:2];
    test_assert([pool count] == 2 && deallocated == 0);
    [pool drain];
    test_assert([pool count] == 0 && deallocated == 2 && last == 1);
  }

  // One which has been retained isn't deallocated
  deallocated = 0;
  Thing *kept = [[Thing thing:3] retain];
  [pool drain];
  test_assert(deallocated == 0 && [kept number] == 3);

  // It can be added more than once
  for (int i = 0; i < 5; i++) {
    test_assert([[kept retain] autorelease] == kept);
  }
  test_assert([pool count] == 5);
  [pool drain];
  test_assert(deallocated == 0);
  [kept autorelease];
  [pool drain];
  test_assert(deallocated == 1);

  // Pools nest
  deallocated = 0;
  [Thing thing:4];
  NXAutoreleasePool *inner = [[NXAutoreleasePool alloc] init];
  test_assert([NXAutoreleasePool currentPool] == inner);
  [Thing thing:5];
  test_assert([inner count] == 1 && [pool count] == 1);
  [inner release];
  test_assert([NXAutoreleasePool currentPool] == pool);
  test_assert(deallocated == 1 && last == 5 && [pool count] == 1);
  [pool drain];
  test_assert(deallocated == 2 && last == 4);

  // Objects which are autoreleased while draining are released as well
  deallocated = 0;
  [Chain thing:50];
  test_assert([pool count] == 1);
  [pool drain];
  test_assert([pool count] == 0 && deallocated == 51 && last == 0);

  // That includes when the pool is released
  deallocated = 0;
  inner = [[NXAutoreleasePool alloc] init];
  [Chain thing:50];
  [inner release];
  test_assert(deallocated == 51 && [pool count] == 0);

  // Many objects
  deallocated = 0;
  for (int i = 0; i < MANY; i++) {
    test_assert([Thing thing:i] != nil);
  }
  test_assert([pool count] == MANY && deallocated == 0);

  // Nothing happens for nil
  Thing *none = nil;
  test_assert([none autorelease] == nil);
  [pool addObject:nil];
  test_assert([pool count] == MANY);

  [pool release];
  test_assert(deallocated == MANY && last == 0);
  test_assert([NXAutoreleasePool currentPool] == nil);
}

test_main(0) {
  pools();

  // The same in a zone, all of which is freed
  NXZone *zone = [NXZone zoneWithSize:4096];
  test_assert(zone != nil);
  pools();
  test_assert([zone count] == 0);
  [zone release];

  // An empty pool
  [[[NXAutoreleasePool alloc] init] release];
  test_assert([NXAutoreleasePool currentPool] == nil);
}
