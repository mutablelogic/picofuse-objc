#include "../../src/Foundation/NXNumber+Private.h"
#include <Foundation/Foundation.h>
#include <test/test.h>

// A number, and its value
typedef struct {
  NXNumber *number;
  BOOL negative;
  uint64_t magnitude;
} value_t;

#define MAX_VALUES 48
static value_t values[MAX_VALUES];
static int count = 0;

static void add(NXNumber *number, BOOL negative, uint64_t magnitude) {
  test_assert(number != nil && count < MAX_VALUES);
  test_assert([number isKindOfClass:[NXNumber class]]);
  test_assert([number boolValue] == (magnitude != 0));
  value_t value = {number, negative, magnitude};
  values[count++] = value;
}

#define ADD_SIGNED(type, value)                                                \
  do {                                                                         \
    int64_t _value = (value);                                                  \
    add([NXNumber numberWith##type:(value)], _value < 0,                       \
        _value < 0 ? -(uint64_t)_value : (uint64_t)_value);                    \
  } while (0)
#define ADD_UNSIGNED(type, value)                                              \
  add([NXNumber numberWith##type:(value)], NO, (value))

// Numbers are equal if their values are, whatever they were made from
static void equality(void) {
  for (int i = 0; i < count; i++) {
    for (int j = 0; j < count; j++) {
      BOOL equal = values[i].negative == values[j].negative &&
                   values[i].magnitude == values[j].magnitude;
      test_assert([values[i].number isEqual:values[j].number] == equal);
    }
    test_assert(![values[i].number isEqual:nil]);
    test_assert(![values[i].number isEqual:@"1"]);
    test_assert(![values[i].number isEqual:[NXNumber class]]);
  }
}

// A number's kind: a floating point number, an unsigned integer, or neither
static void kind(NXNumber *number, BOOL isFloat, BOOL isUnsigned) {
  test_assert(number != nil);
  test_assert([number isFloat] == isFloat);
  test_assert([number isUnsigned] == isUnsigned);
}

// Each factory's numbers are of its kind, and so is each zero
static void kinds(void) {
  kind([NXNumber zeroValue], NO, NO);
  kind([NXNumber numberWithInt16:0], NO, NO);
  kind([NXNumber numberWithInt32:0], NO, NO);
  kind([NXNumber numberWithInt64:0], NO, NO);
  kind([NXNumber numberWithUnsignedInt16:0], NO, YES);
  kind([NXNumber numberWithUnsignedInt32:0], NO, YES);
  kind([NXNumber numberWithUnsignedInt64:0], NO, YES);
  kind([NXNumber numberWithFloat32:0], YES, NO);
  kind([NXNumber numberWithFloat64:0], YES, NO);
  kind([NXNumber numberWithFloat32:-0.0f], YES, NO);
  kind([NXNumber numberWithFloat64:-0.0], YES, NO);

  kind([NXNumber numberWithInt16:-1], NO, NO);
  kind([NXNumber numberWithInt32:1], NO, NO);
  kind([NXNumber numberWithInt64:INT64_MIN], NO, NO);
  kind([NXNumber numberWithUnsignedInt16:1], NO, YES);
  kind([NXNumber numberWithUnsignedInt32:UINT32_MAX], NO, YES);
  kind([NXNumber numberWithUnsignedInt64:UINT64_MAX], NO, YES);
  kind([NXNumber numberWithFloat32:1.5f], YES, NO);
  kind([NXNumber numberWithFloat64:-2.5], YES, NO);

  kind([NXNumber trueValue], NO, NO);
  kind([NXNumber falseValue], NO, NO);
}

// There's only one of each zero, true and false, and they don't need a pool. The
// zeros are a signed integer, an unsigned integer and a float, and are equal.
static void statics(void) {
  NXNumber *zero = [NXNumber zeroValue];
  NXNumber *yes = [NXNumber trueValue];
  NXNumber *no = [NXNumber falseValue];
  test_assert(zero != nil && yes != nil && no != nil);
  test_assert(zero != no && yes != no && zero != yes);
  test_assert(zero == [NXNumber zeroValue]);
  test_assert(yes == [NXNumber numberWithBool:YES]);
  test_assert(no == [NXNumber numberWithBool:NO]);
  test_assert(zero == [NXNumber numberWithInt16:0]);
  test_assert(zero == [NXNumber numberWithInt32:0]);
  test_assert(zero == [NXNumber numberWithInt64:0]);
  NXNumber *unsignedZero = [NXNumber numberWithUnsignedInt16:0];
  test_assert(unsignedZero != zero);
  test_assert(unsignedZero == [NXNumber numberWithUnsignedInt32:0]);
  test_assert(unsignedZero == [NXNumber numberWithUnsignedInt64:0]);
  NXNumber *floatZero = [NXNumber numberWithFloat64:0];
  test_assert(floatZero != zero && floatZero != unsignedZero);
  test_assert(floatZero == [NXNumber numberWithFloat32:0]);
  test_assert([zero isEqual:unsignedZero] && [zero isEqual:floatZero] &&
              [unsignedZero isEqual:floatZero]);
  test_assert([zero hash] == [unsignedZero hash] && [zero hash] == [floatZero hash]);
  test_assert([zero compare:floatZero] == NXComparisonSame &&
              [unsignedZero compare:floatZero] == NXComparisonSame);
  test_assert([[unsignedZero description] isEqual:@"0"] &&
              [[floatZero description] isEqual:@"0"]);
  test_assert([floatZero float64Value] == 0.0 && [unsignedZero unsignedInt64Value] == 0);
  [unsignedZero release]; // static, so it's not deallocated
  [floatZero release];
  test_assert([NXNumber numberWithFloat32:0] == floatZero);

  test_assert(![zero boolValue] && [yes boolValue] && ![no boolValue]);
  test_assert([zero int16Value] == 0 && [zero unsignedInt64Value] == 0);
  test_assert([yes int16Value] == 1 && [yes unsignedInt64Value] == 1);
  test_assert([no int64Value] == 0 && [no unsignedInt32Value] == 0);
  test_assert([zero isEqual:no] && [no isEqual:zero] && ![zero isEqual:yes]);

  // They're not affected by being released
  for (int i = 0; i < 3; i++) {
    [zero release];
    [yes release];
    test_assert([no retain] == no && [no autorelease] == no);
  }
  test_assert([zero zone] == nil && [yes zone] == nil);
  test_assert(![zero boolValue] && [yes boolValue] && ![no boolValue]);
}

static void numbers(void) {
  count = 0;
  add([NXNumber zeroValue], NO, 0);
  add([NXNumber falseValue], NO, 0);
  add([NXNumber trueValue], NO, 1);

  // Each type can be returned as any other, if it's in range
#define CHECK(number, value)                                                   \
  do {                                                                         \
    NXNumber *_number = (number);                                              \
    test_assert([_number int16Value] == (value));                              \
    test_assert([_number unsignedInt16Value] == (value));                      \
    test_assert([_number int32Value] == (value));                              \
    test_assert([_number unsignedInt32Value] == (value));                      \
    test_assert([_number int64Value] == (value));                              \
    test_assert([_number unsignedInt64Value] == (value));                      \
  } while (0)
  CHECK([NXNumber numberWithInt16:42], 42);
  CHECK([NXNumber numberWithUnsignedInt16:42], 42);
  CHECK([NXNumber numberWithInt32:42], 42);
  CHECK([NXNumber numberWithUnsignedInt32:42], 42);
  CHECK([NXNumber numberWithInt64:42], 42);
  CHECK([NXNumber numberWithUnsignedInt64:42], 42);

  // Negative values, and the limits of each type
  test_assert([[NXNumber numberWithInt64:-42] int16Value] == -42);
  test_assert([[NXNumber numberWithInt16:-42] int64Value] == -42);
  test_assert([[NXNumber numberWithInt64:INT16_MIN] int16Value] == INT16_MIN);
  test_assert([[NXNumber numberWithInt64:INT16_MAX] int16Value] == INT16_MAX);
  test_assert([[NXNumber numberWithInt64:INT32_MIN] int32Value] == INT32_MIN);
  test_assert([[NXNumber numberWithInt64:INT64_MIN] int64Value] == INT64_MIN);
  test_assert([[NXNumber numberWithInt64:INT64_MAX] int64Value] == INT64_MAX);
  test_assert([[NXNumber numberWithInt64:INT64_MAX] unsignedInt64Value] ==
              INT64_MAX);
  test_assert([[NXNumber numberWithUnsignedInt64:UINT16_MAX]
                  unsignedInt16Value] == UINT16_MAX);
  test_assert([[NXNumber numberWithUnsignedInt64:UINT64_MAX]
                  unsignedInt64Value] == UINT64_MAX);
  test_assert([[NXNumber numberWithInt64:INT64_MIN] boolValue]);

  // Every pair of these is compared
  ADD_SIGNED(Int16, 1);
  ADD_SIGNED(Int32, 1);
  ADD_SIGNED(Int64, 1);
  ADD_UNSIGNED(UnsignedInt16, 1);
  ADD_UNSIGNED(UnsignedInt32, 1);
  ADD_UNSIGNED(UnsignedInt64, 1);
  ADD_SIGNED(Int16, -1);
  ADD_SIGNED(Int32, -1);
  ADD_SIGNED(Int64, -1);
  ADD_UNSIGNED(UnsignedInt16, UINT16_MAX);
  ADD_UNSIGNED(UnsignedInt32, UINT16_MAX);
  ADD_UNSIGNED(UnsignedInt32, UINT32_MAX);
  ADD_UNSIGNED(UnsignedInt64, UINT32_MAX);
  ADD_UNSIGNED(UnsignedInt64, UINT64_MAX);
  ADD_UNSIGNED(UnsignedInt64, (uint64_t)INT64_MAX);
  ADD_UNSIGNED(UnsignedInt64, (uint64_t)INT64_MAX + 1);
  ADD_SIGNED(Int16, INT16_MIN);
  ADD_SIGNED(Int32, INT16_MIN);
  ADD_SIGNED(Int32, INT32_MIN);
  ADD_SIGNED(Int64, INT32_MIN);
  ADD_SIGNED(Int64, INT64_MIN);
  ADD_SIGNED(Int64, INT64_MAX);
  equality();
}

// Equality of floating point numbers and others, both ways round
static void equal(NXNumber *a, NXNumber *b, BOOL expected) {
  test_assert([a isEqual:b] == expected);
  test_assert([b isEqual:a] == expected);
}

static void floats(void) {
  NXNumber *f, *d;

  // As other types
  f = [NXNumber numberWithFloat32:2.75f];
  d = [NXNumber numberWithFloat64:-2.75];
  test_assert([f float32Value] == 2.75f && [f float64Value] == 2.75);
  test_assert([d float32Value] == -2.75f && [d float64Value] == -2.75);
  test_assert([f int16Value] == 2 && [f unsignedInt64Value] == 2);
  test_assert([d int16Value] == -2 && [d int64Value] == -2);
  test_assert([[NXNumber numberWithFloat64:-0.5] int32Value] == 0);
  test_assert([[NXNumber numberWithFloat64:-0.5] unsignedInt32Value] == 0);
  test_assert([[NXNumber numberWithFloat64:0.5] boolValue]);
  test_assert([[NXNumber numberWithInt16:-3] float32Value] == -3.0f);
  test_assert([[NXNumber numberWithUnsignedInt64:UINT64_MAX] float64Value] ==
              18446744073709551616.0);
  test_assert([[NXNumber numberWithInt64:INT64_MIN] float64Value] ==
              -9223372036854775808.0);
  test_assert([[NXNumber trueValue] float32Value] == 1.0f);
  test_assert([[NXNumber zeroValue] float64Value] == 0.0);

  // The limits of integers
  test_assert([[NXNumber numberWithFloat64:-9223372036854775808.0] int64Value] ==
              INT64_MIN);
  test_assert([[NXNumber numberWithFloat64:18446744073709549568.0]
                  unsignedInt64Value] == UINT64_MAX - 2047);
  test_assert([[NXNumber numberWithFloat64:32767.9] int16Value] == INT16_MAX);

  // Zero, which is the float zero, and negative zero which is another object but equal
  // to it
  NXNumber *zero = [NXNumber numberWithFloat64:0];
  test_assert([NXNumber numberWithFloat32:0] == zero);
  test_assert(zero != [NXNumber zeroValue] && [zero isEqual:[NXNumber zeroValue]]);
  f = [NXNumber numberWithFloat32:-0.0f];
  d = [NXNumber numberWithFloat64:-0.0];
  test_assert(f != zero && d != zero && ![f boolValue] && ![d boolValue]);
  test_assert(__builtin_signbit([f float32Value]));
  test_assert(__builtin_signbit([d float64Value]));
  equal(f, zero, YES);
  equal(d, zero, YES);
  equal(f, d, YES);
  equal(d, [NXNumber falseValue], YES);

  // Integers which are, or aren't, exactly the same
  equal([NXNumber numberWithFloat32:1], [NXNumber trueValue], YES);
  equal([NXNumber numberWithFloat64:-7], [NXNumber numberWithInt16:-7], YES);
  equal([NXNumber numberWithFloat64:7], [NXNumber numberWithInt16:-7], NO);
  equal([NXNumber numberWithFloat64:7.5], [NXNumber numberWithInt16:7], NO);
  equal([NXNumber numberWithFloat64:0.5], zero, NO);
  equal([NXNumber numberWithFloat64:-0.5], zero, NO);
  double exact = 9007199254740992.0; // Two to the power of 53
  equal([NXNumber numberWithFloat64:exact],
        [NXNumber numberWithInt64:9007199254740992], YES);
  equal([NXNumber numberWithFloat64:exact],
        [NXNumber numberWithInt64:9007199254740993], NO);
  equal([NXNumber numberWithFloat64:18446744073709551616.0],
        [NXNumber numberWithUnsignedInt64:UINT64_MAX], NO);
  equal([NXNumber numberWithFloat64:-9223372036854775808.0],
        [NXNumber numberWithInt64:INT64_MIN], YES);

  // Each other
  equal([NXNumber numberWithFloat32:0.5f], [NXNumber numberWithFloat64:0.5], YES);
  equal([NXNumber numberWithFloat32:0.1f], [NXNumber numberWithFloat64:0.1], NO);

  // Infinity, and what isn't a number
  d = [NXNumber numberWithFloat64:__builtin_inf()];
  f = [NXNumber numberWithFloat32:__builtin_inff()];
  equal(d, f, YES);
  equal(d, [NXNumber numberWithFloat64:-__builtin_inf()], NO);
  equal(d, [NXNumber numberWithUnsignedInt64:UINT64_MAX], NO);
  test_assert([[NXNumber numberWithFloat64:1e300] float32Value] ==
              __builtin_inff());
  d = [NXNumber numberWithFloat64:__builtin_nan("")];
  f = [NXNumber numberWithFloat32:__builtin_nanf("")];
  test_assert([d boolValue] && [d float64Value] != [d float64Value]);
  test_assert([d isEqual:d]);
  equal(d, f, NO);
  equal(d, zero, NO);
  equal(f, [NXNumber numberWithFloat64:__builtin_nan("")], NO);
}

// Random numbers are of the right type, and it's unlikely that they're all the same
static void randoms(void) {
  int different = 0, negative = 0, large = 0;
  for (int i = 0; i < 64; i++) {
    different += ![[NXNumber randomInt32] isEqual:[NXNumber randomInt32]];
    different += ![[NXNumber randomUnsignedInt32]
        isEqual:[NXNumber randomUnsignedInt32]];
    different += ![[NXNumber randomInt64] isEqual:[NXNumber randomInt64]];
    different += ![[NXNumber randomUnsignedInt64]
        isEqual:[NXNumber randomUnsignedInt64]];
    different += NXRandInt64() != NXRandInt64();
    different += NXRandUnsignedInt64() != NXRandUnsignedInt64();
    negative += [[NXNumber randomInt32] int32Value] < 0;
    negative += [[NXNumber randomInt64] int64Value] < 0;
    large += [[NXNumber randomUnsignedInt32] unsignedInt32Value] > INT32_MAX;
    large += [[NXNumber randomUnsignedInt64] unsignedInt64Value] > UINT32_MAX;
  }
  test_assert(different > 300 && negative > 0 && negative < 128 && large > 64);
}

test_main(0) {
  test_assert([NXAutoreleasePool currentPool] == nil);
  statics();

  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  statics();
  numbers();
  floats();
  kinds();
  randoms();
  NXNumber *kept = [[NXNumber numberWithInt32:-7] retain];
  [pool release];
  test_assert([kept int32Value] == -7);
  [kept release];
  statics();

  // In a zone, zero, true and false aren't
  NXZone *zone = [NXZone zoneWithSize:4096];
  test_assert(zone != nil);
  pool = [[NXAutoreleasePool alloc] init];
  test_assert([[NXNumber numberWithInt16:1] zone] == zone);
  statics();
  numbers();
  floats();
  [pool release];
  test_assert([zone count] == 0);
  [zone release];
  statics();

  // It's unlikely that they're all the same
  int32_t random = NXRandInt32();
  uint32_t random_unsigned = NXRandUnsignedInt32();
  int different = 0;
  for (int i = 0; i < 8; i++) {
    different += NXRandInt32() != random;
    different += NXRandUnsignedInt32() != random_unsigned;
  }
  test_assert(different > 0);
}
