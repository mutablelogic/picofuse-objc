#include "NXObject+Private.h"
#include "NXZone+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <string.h>

// The least a map has room for, once it has any
#define CAPACITY_MIN 8

// A key and its object, or an empty slot if the key is nil
typedef struct {
  id key;
  id object;
} entry_t;

@interface NXMap (Private)
- (BOOL)resize:(size_t)capacity;
- (size_t)find:(id)key;
- (void)removeAtIndex:(size_t)index;
@end

// Returns the size of table needed for a number of keys, so it's no more than three
// quarters full, or zero if it's too many
static size_t capacity_for(size_t count) {
  size_t capacity = CAPACITY_MIN;
  while (capacity / 4 * 3 < count) {
    if (capacity > SIZE_MAX / 2 / sizeof(entry_t)) {
      return 0;
    }
    capacity *= 2;
  }
  return capacity;
}

@implementation NXMap

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

+ (id)map {
  return [[[self alloc] init] autorelease];
}

+ (id)mapWithCapacity:(size_t)capacity {
  return [[[self alloc] initWithCapacity:capacity] autorelease];
}

+ (id)mapWithKeysAndObjects:(id)firstKey, ... {
  NXMap *map = [[[self alloc] init] autorelease];
  va_list args;
  va_start(args, firstKey);
  for (id key = firstKey; map != nil && key != nil; key = va_arg(args, id)) {
    id object = va_arg(args, id);
    if (![map setObject:object forKey:key]) {
      map = nil;
    }
  }
  va_end(args);
  return map;
}

- (id)initWithCapacity:(size_t)capacity {
  self = [super init];
  if (self != nil && capacity > 0) {
    size_t size = capacity_for(capacity);
    if (size == 0 || ![self resize:size]) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  [self removeAllObjects];
  NXZoneFree([self zone], _entries);
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

- (size_t)count {
  return _count;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

- (id)objectForKey:(id)key {
  size_t index = [self find:key];
  return index == NXNotFound ? nil : ((entry_t *)_entries)[index].object;
}

- (BOOL)containsObject:(id)key {
  return [self find:key] != NXNotFound;
}

- (BOOL)setObject:(id)object forKey:(id)key {
  if (object == nil || key == nil) {
    return NO;
  }

  // Replace the object, releasing the old one once it's out of the map, in case its
  // dealloc uses the map
  size_t index = [self find:key];
  if (index != NXNotFound) {
    entry_t *entry = &((entry_t *)_entries)[index];
    id old = entry->object;
    entry->object = [object retain];
    [old release];
    return YES;
  }

  // Or else add it, making room if it would be more than three quarters full
  if (_count + 1 > _capacity / 4 * 3) {
    size_t capacity = capacity_for(_count + 1);
    if (capacity == 0 || ![self resize:capacity]) {
      return NO;
    }
  }
  id copy = [key copy];
  if (copy == nil) {
    return NO;
  }
  entry_t *entries = _entries;
  size_t mask = _capacity - 1;
  size_t i = (size_t)(((uint64_t)[copy hash] * UINT64_C(0x9E3779B97F4A7C15)) >> _shift);
  while (entries[i].key != nil) {
    i = (i + 1) & mask;
  }
  entries[i].key = copy;
  entries[i].object = [object retain];
  _count++;
  return YES;
}

- (BOOL)removeObjectForKey:(id)key {
  size_t index = [self find:key];
  if (index == NXNotFound) {
    return NO;
  }
  [self removeAtIndex:index];
  return YES;
}

- (void)removeAllObjects {
  // Each is removed as removeObjectForKey: does, so what's left can always be found. A
  // dealloc may change the map, so look again until it's empty.
  while (_count > 0) {
    for (size_t i = 0; i < _capacity && _count > 0; i++) {
      while (i < _capacity && ((entry_t *)_entries)[i].key != nil) {
        [self removeAtIndex:i];
      }
    }
  }
}

- (NXArray *)allKeys {
  NXArray *keys = [NXArray arrayWithCapacity:_count];
  entry_t *entries = _entries;
  for (size_t i = 0; keys != nil && i < _capacity; i++) {
    if (entries[i].key != nil && ![keys appendObject:entries[i].key]) {
      return nil;
    }
  }
  return keys;
}

- (NXArray *)allObjects {
  NXArray *objects = [NXArray arrayWithCapacity:_count];
  entry_t *entries = _entries;
  for (size_t i = 0; objects != nil && i < _capacity; i++) {
    if (entries[i].key != nil && ![objects appendObject:entries[i].object]) {
      return nil;
    }
  }
  return objects;
}

- (BOOL)isEqual:(id)anObject {
  if (anObject == self) {
    return YES;
  }
  if (anObject == nil || !object_isKindOfClass(anObject, [NXMap class])) {
    return NO;
  }
  NXMap *other = anObject;
  if (other->_count != _count) {
    return NO;
  }
  entry_t *entries = _entries;
  for (size_t i = 0; i < _capacity; i++) {
    if (entries[i].key != nil) {
      id object = [other objectForKey:entries[i].key];
      if (object == nil || (object != entries[i].object &&
                            ![object isEqual:entries[i].object])) {
        return NO;
      }
    }
  }
  return YES;
}

- (uintptr_t)hash {
  // Added, as the order of the keys isn't defined
  uintptr_t hash = _count;
  entry_t *entries = _entries;
  for (size_t i = 0; i < _capacity; i++) {
    if (entries[i].key != nil) {
      hash += NXHashCombine([entries[i].key hash], [entries[i].object hash]);
    }
  }
  return hash;
}

- (id)copy {
  NXMap *copy = [[NXMap allocInZone:[self zone]] initWithCapacity:_count];
  entry_t *entries = _entries;
  for (size_t i = 0; copy != nil && i < _capacity; i++) {
    if (entries[i].key != nil &&
        ![copy setObject:entries[i].object forKey:entries[i].key]) {
      [copy release];
      copy = nil;
    }
  }
  return copy;
}

- (NXString *)description {
  NXMutableString *description = [NXMutableString stringWithCString:"{"];
  entry_t *entries = _entries;
  BOOL first = YES;
  for (size_t i = 0; description != nil && i < _capacity; i++) {
    if (entries[i].key != nil) {
      if (![description appendFormat:first ? @"%@: %@" : @", %@: %@", entries[i].key,
                                     entries[i].object]) {
        return nil;
      }
      first = NO;
    }
  }
  return [description appendCString:"}"] ? description : nil;
}

@end

@implementation NXMap (Private)

// Moves the keys and objects into a table of a size, which is a power of two
- (BOOL)resize:(size_t)capacity {
  entry_t *entries = NXZoneAlloc([self zone], capacity * sizeof(entry_t));
  if (entries == NULL) {
    return NO;
  }
  memset(entries, 0, capacity * sizeof(entry_t));
  unsigned shift = 64;
  for (size_t size = capacity; size > 1; size >>= 1) {
    shift--;
  }

  // Their hashes have already been found, so nothing can change the map while they move
  entry_t *old = _entries;
  size_t mask = capacity - 1;
  for (size_t i = 0; i < _capacity; i++) {
    if (old[i].key != nil) {
      size_t j =
          (size_t)(((uint64_t)[old[i].key hash] * UINT64_C(0x9E3779B97F4A7C15)) >> shift);
      while (entries[j].key != nil) {
        j = (j + 1) & mask;
      }
      entries[j] = old[i];
    }
  }
  NXZoneFree([self zone], old);
  _entries = entries;
  _capacity = capacity;
  _shift = shift;
  return YES;
}

// Removes the key and object at an index, moving back those after it which would
// otherwise not be found, so there are no gaps between where a key belongs and where it
// is. They're released once they're out of the map, in case their dealloc uses it.
- (void)removeAtIndex:(size_t)index {
  entry_t *entries = _entries;
  size_t mask = _capacity - 1;
  entry_t removed = entries[index];
  size_t hole = index;
  for (size_t i = (hole + 1) & mask; entries[i].key != nil; i = (i + 1) & mask) {
    size_t home =
        (size_t)(((uint64_t)[entries[i].key hash] * UINT64_C(0x9E3779B97F4A7C15)) >>
                 _shift);
    if (((i - home) & mask) >= ((i - hole) & mask)) {
      entries[hole] = entries[i];
      hole = i;
    }
  }
  entries[hole].key = nil;
  entries[hole].object = nil;
  _count--;
  [removed.key release];
  [removed.object release];
}

// Returns the index of a key in the table, or NXNotFound
- (size_t)find:(id)key {
  if (key == nil || _count == 0) {
    return NXNotFound;
  }
  entry_t *entries = _entries;
  size_t mask = _capacity - 1;
  size_t i = (size_t)(((uint64_t)[key hash] * UINT64_C(0x9E3779B97F4A7C15)) >> _shift);
  while (entries[i].key != nil) {
    if (entries[i].key == key || [entries[i].key isEqual:key]) {
      return i;
    }
    i = (i + 1) & mask;
  }
  return NXNotFound;
}

@end
