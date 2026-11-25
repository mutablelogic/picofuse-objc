#include <Foundation/Foundation.h>
#include <test/test.h>

#define BLOCKS 64

test_main(0) {
  // Zones can't be made any other way, and have to have a size
  test_assert([[NXZone alloc] init] == nil);
  test_assert([NXZone zoneWithSize:0] == nil);
  test_assert([NXZone defaultZone] == nil);

  // The first is the default, and zones aren't allocated in zones
  NXZone *zone = [NXZone zoneWithSize:512];
  NXZone *other = [NXZone zoneWithSize:512];
  test_assert(zone != nil && other != nil && zone != other);
  test_assert([NXZone defaultZone] == zone);
  test_assert([zone zone] == nil && [other zone] == nil);
  test_assert([zone count] == 0 && [zone bytesUsed] == 0);

  // Statistics
  size_t total = [zone bytesTotal];
  test_assert(total >= 512 && [zone bytesFree] == total);
  void *ptr = [zone allocWithSize:100];
  test_assert(ptr != NULL);
  test_assert([zone count] == 1 && [zone bytesUsed] == 100);
  test_assert([zone bytesFree] == total - 100 && [zone bytesTotal] == total);
  test_assert([other count] == 0);
  [zone free:ptr];
  [zone free:NULL];
  test_assert([zone count] == 0 && [zone bytesUsed] == 0);
  test_assert([zone allocWithSize:0] == NULL);

  // Memory which has been freed is used again, so the zone doesn't grow
  for (int i = 0; i < 200; i++) {
    ptr = [zone allocWithSize:200];
    test_assert(ptr != NULL);
    [zone free:ptr];
  }
  test_assert([zone bytesTotal] == total);

  // The zone grows, including for what's larger than its size
  unsigned char *blocks[BLOCKS];
  for (int i = 0; i < BLOCKS; i++) {
    blocks[i] = [zone allocWithSize:50 + i];
    test_assert(blocks[i] != NULL);
    memset(blocks[i], i, 50 + i);
  }
  unsigned char *large = [zone allocWithSize:2000];
  test_assert(large != NULL);
  memset(large, 0xFF, 2000);
  test_assert([zone count] == BLOCKS + 1 && [zone bytesTotal] > total);
  for (int i = 0; i < BLOCKS; i++) {
    for (int j = 0; j < 50 + i; j++) {
      test_assert(blocks[i][j] == i);
    }
  }

  // It can be freed in any order
  [zone free:large];
  for (int i = 0; i < BLOCKS; i += 2) {
    [zone free:blocks[i]];
  }
  for (int i = BLOCKS - 1; i > 0; i -= 2) {
    [zone free:blocks[i]];
  }
  test_assert([zone count] == 0 && [zone bytesUsed] == 0);

  // Objects can be allocated in a zone which isn't the default
  NXObject *object = [[NXObject allocWithZone:other] init];
  test_assert(object != nil && [object zone] == other);
  test_assert([other count] == 1 && [zone count] == 0);
  [object release];
  test_assert([other count] == 0);

  // Once the default is gone there isn't one, until there's another new zone
  [zone release];
  test_assert([NXZone defaultZone] == nil);
  zone = [NXZone zoneWithSize:512];
  test_assert([NXZone defaultZone] == zone);

  // A zone can be retained
  [zone retain];
  [zone release];
  test_assert([NXZone defaultZone] == zone);
  [zone release];
  test_assert([NXZone defaultZone] == nil);
  [other release];

  // Zones don't use up anything
  for (int i = 0; i < 100; i++) {
    zone = [NXZone zoneWithSize:512];
    test_assert(zone != nil);
    [zone release];
  }
}
