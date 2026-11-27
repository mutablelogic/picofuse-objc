#include "NXFastEnumeration+Private.h"
#include "NXObject+Private.h"
#include "NXZone+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <string.h>

// The least an array has room for, once it has any
#define CAPACITY_MIN 4

@interface NXArray (Private)
- (BOOL)reserve:(size_t)capacity;
@end

@implementation NXArray

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

+ (id)array {
  return [[[self alloc] init] autorelease];
}

+ (id)arrayWithCapacity:(size_t)capacity {
  return [[[self alloc] initWithCapacity:capacity] autorelease];
}

+ (id)arrayWithObjects:(id)firstObject, ... {
  NXArray *array = [[[self alloc] init] autorelease];
  va_list args;
  va_start(args, firstObject);
  for (id object = firstObject; array != nil && object != nil;
       object = va_arg(args, id)) {
    if (![array appendObject:object]) {
      array = nil;
    }
  }
  va_end(args);
  return array;
}

- (id)initWithCapacity:(size_t)capacity {
  self = [super init];
  if (self != nil && capacity > 0 && ![self reserve:capacity]) {
    [self release];
    return nil;
  }
  return self;
}

- (id)initWithObjects:(id)firstObject, ... {
  self = [super init];
  va_list args;
  va_start(args, firstObject);
  for (id object = firstObject; self != nil && object != nil;
       object = va_arg(args, id)) {
    if (![self appendObject:object]) {
      [self release];
      self = nil;
    }
  }
  va_end(args);
  return self;
}

- (void)dealloc {
  [self removeAllObjects];
  NXZoneFree([self zone], _objects);
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

- (size_t)count {
  return _count;
}

- (size_t)capacity {
  return _capacity;
}

- (id)objectAtIndex:(size_t)index {
  return index < _count ? _objects[index] : nil;
}

- (id)firstObject {
  return _count > 0 ? _objects[0] : nil;
}

- (id)lastObject {
  return _count > 0 ? _objects[_count - 1] : nil;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

- (size_t)indexOfObject:(id)object {
  if (object != nil) {
    for (size_t i = 0; i < _count; i++) {
      if (_objects[i] == object || [_objects[i] isEqual:object]) {
        return i;
      }
    }
  }
  return NXNotFound;
}

- (BOOL)containsObject:(id)object {
  return [self indexOfObject:object] != NXNotFound;
}

- (BOOL)appendObject:(id)object {
  return [self insertObject:object atIndex:_count];
}

- (BOOL)insertObject:(id)object atIndex:(size_t)index {
  if (object == nil || index > _count) {
    return NO;
  }

  // Twice the room, when there's none left
  if (_count == _capacity) {
    if (_capacity > SIZE_MAX / 2) {
      return NO;
    }
    size_t capacity = _capacity < CAPACITY_MIN ? CAPACITY_MIN : _capacity * 2;
    if (![self reserve:capacity]) {
      return NO;
    }
  }
  memmove(&_objects[index + 1], &_objects[index], (_count - index) * sizeof(id));
  _objects[index] = [object retain];
  _count++;
  _mutations++;
  return YES;
}

- (BOOL)replaceObjectAtIndex:(size_t)index withObject:(id)object {
  if (object == nil || index >= _count) {
    return NO;
  }

  // The old one is released once it's out of the array, in case its dealloc
  // uses the array, and the new one is retained first, in case it's the same
  id old = _objects[index];
  _objects[index] = [object retain];
  [old release];
  return YES;
}

- (BOOL)removeObjectAtIndex:(size_t)index {
  if (index >= _count) {
    return NO;
  }

  // Released once it's out of the array, in case its dealloc uses the array
  id object = _objects[index];
  _count--;
  _mutations++;
  memmove(&_objects[index], &_objects[index + 1], (_count - index) * sizeof(id));
  [object release];
  return YES;
}

- (size_t)removeObject:(id)object {
  size_t removed = 0;
  if (object == nil) {
    return 0;
  }

  // Retained, in case it's only kept by the array
  [object retain];
  for (size_t i = _count; i > 0; i--) {
    if (_objects[i - 1] == object || [_objects[i - 1] isEqual:object]) {
      [self removeObjectAtIndex:i - 1];
      removed++;
    }
  }
  [object release];
  return removed;
}

- (BOOL)removeLastObject {
  return _count > 0 && [self removeObjectAtIndex:_count - 1];
}

- (void)removeAllObjects {
  while (_count > 0) {
    [self removeObjectAtIndex:_count - 1];
  }
}

- (uintptr_t)hash {
  uintptr_t hash = _count;
  for (size_t i = 0; i < _count; i++) {
    hash = NXHashCombine(hash, [_objects[i] hash]);
  }
  return hash;
}

- (id)copy {
  NXArray *copy = [[NXArray allocInZone:[self zone]] initWithCapacity:_count];
  for (size_t i = 0; copy != nil && i < _count; i++) {
    if (![copy appendObject:_objects[i]]) {
      [copy release];
      copy = nil;
    }
  }
  return copy;
}

// The objects are one after another, so they're given to the loop as they are, in one
// batch. They move if objects are added or removed, so those are counted.
- (unsigned long)countByEnumeratingWithState:(NXFastEnumerationState *)state
                                     objects:(id *)objects
                                       count:(unsigned long)count {
  (void)objects;
  (void)count;
  state->mutationsPtr = &_mutations;
  if (state->state != 0) {
    return 0;
  }
  state->state = 1;
  state->itemsPtr = _objects;
  return (unsigned long)_count;
}

- (BOOL)isEqual:(id)anObject {
  if (anObject == self) {
    return YES;
  }
  if (anObject == nil || !object_isKindOfClass(anObject, [NXArray class])) {
    return NO;
  }
  NXArray *other = anObject;
  if (other->_count != _count) {
    return NO;
  }
  for (size_t i = 0; i < _count; i++) {
    if (_objects[i] != other->_objects[i] &&
        ![_objects[i] isEqual:other->_objects[i]]) {
      return NO;
    }
  }
  return YES;
}

- (NXString *)description {
  NXMutableString *description = [NXMutableString stringWithCString:"["];
  for (size_t i = 0; description != nil && i < _count; i++) {
    if (![description appendFormat:i == 0 ? @"%@" : @", %@", _objects[i]]) {
      return nil;
    }
  }
  return [description appendCString:"]"] ? description : nil;
}

@end

@implementation NXArray (Private)

// Makes room for a number of objects, or returns NO if there isn't enough memory
- (BOOL)reserve:(size_t)capacity {
  if (capacity <= _capacity) {
    return YES;
  }
  if (capacity > SIZE_MAX / sizeof(id)) {
    return NO;
  }
  id *objects = NXZoneRealloc([self zone], _objects, _capacity * sizeof(id),
                              capacity * sizeof(id));
  if (objects == NULL) {
    return NO;
  }
  _objects = objects;
  _capacity = capacity;
  return YES;
}

@end
