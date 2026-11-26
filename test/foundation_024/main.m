#include <Foundation/Foundation.h>
#include <test/test.h>

// Checks two objects are equal, and so have the same hash
static void same(id a, id b) {
  test_assert(a != nil && b != nil);
  test_assert([a isEqual:b] && [b isEqual:a]);
  test_assert([a hash] == [b hash]);
}

static void hashes(void) {
  // Objects are only equal to themselves
  NXObject *object = [[[NXObject alloc] init] autorelease];
  NXObject *other = [[[NXObject alloc] init] autorelease];
  test_assert([object hash] == [object hash] && [object hash] != [other hash]);

  // Strings, of every kind
  NXMutableString *mutable = [NXMutableString stringWithCString:"hello"];
  same(@"hello", [NXString stringWithCString:"hello"]);
  same(@"hello", mutable);
  same(@"", [NXString string]);
  test_assert([@"hello" hash] != [@"world" hash]);
  test_assert([mutable appendCString:"!"] && [mutable hash] != [@"hello" hash]);

  // Numbers which are equal, whatever their type
  same([NXNumber numberWithInt16:1], [NXNumber numberWithUnsignedInt64:1]);
  same([NXNumber numberWithInt32:1], [NXNumber numberWithFloat64:1.0]);
  same([NXNumber numberWithFloat32:1.0f], [NXNumber trueValue]);
  same([NXNumber zeroValue], [NXNumber falseValue]);
  same([NXNumber zeroValue], [NXNumber numberWithFloat64:-0.0]);
  same([NXNumber numberWithFloat64:0.0], [NXNumber numberWithFloat64:-0.0]);
  same([NXNumber numberWithInt64:-5], [NXNumber numberWithFloat32:-5.0f]);
  same([NXNumber numberWithFloat32:0.5f], [NXNumber numberWithFloat64:0.5]);
  same([NXNumber numberWithUnsignedInt64:UINT64_MAX],
       [NXNumber numberWithUnsignedInt64:UINT64_MAX]);
  same([NXNumber numberWithFloat64:1e30], [NXNumber numberWithFloat64:1e30]);
  test_assert([[NXNumber numberWithInt32:1] hash] != [[NXNumber numberWithInt32:-1] hash]);
  test_assert([[NXNumber numberWithInt32:1] hash] != [[NXNumber numberWithInt32:2] hash]);

  // Dates at the same moment, in any time zone
  NXDate *date = [NXDate dateWithSeconds:1788694625 nanoseconds:5];
  same(date, [date dateWithTimeZoneOffset:3600]);
  same(date, [NXDate dateWithSeconds:1788694625 nanoseconds:5]);
  test_assert([date hash] != [[date dateByAddingDuration:1] hash]);

  // Null
  same([NXNull nullValue], [NXNull nullValue]);

  // Arrays of equal objects
  NXArray *a = [NXArray arrayWithObjects:@"a", [NXNumber numberWithInt32:1], nil];
  NXArray *b = [NXArray arrayWithObjects:[NXString stringWithCString:"a"],
                                         [NXNumber numberWithFloat64:1.0], nil];
  same(a, b);
  same([NXArray array], [NXArray array]);
  NXArray *c = [NXArray arrayWithObjects:[NXNumber numberWithInt32:1], @"a", nil];
  test_assert([a hash] != [c hash]);
}

static void copies(NXZone *zone) {
  // Those which can't change are the same object, retained
  id immutable[] = {@"constant", [NXString stringWithCString:"heap"],
                    [NXNumber numberWithInt32:42], [NXNumber zeroValue],
                    [NXNull nullValue], [NXDate dateWithSeconds:0 nanoseconds:0]};
  for (size_t i = 0; i < sizeof(immutable) / sizeof(immutable[0]); i++) {
    id copy = [immutable[i] copy];
    test_assert(copy == immutable[i]);
    [copy release];
  }
  NXObject *object = [[NXObject alloc] init];
  NXObject *copy = [object copy];
  test_assert(copy == object);
  [copy release];
  [object release];

  // A mutable string is copied to a string which can't change
  NXMutableString *mutable = [NXMutableString stringWithCString:"before"];
  NXString *string = [mutable copy];
  test_assert(string != mutable && [string zone] == zone);
  test_assert(!object_isKindOfClass(string, [NXMutableString class]));
  same(string, mutable);
  test_assert([mutable appendCString:" after"]);
  test_assert_strequal([string cStr], "before");
  NXString *again = [string copy];
  test_assert(again == string);
  [again release];
  [string release];
  string = [[NXMutableString string] copy];
  test_assert(string != nil && [string length] == 0);
  [string release];

  // An array is copied to a new one, of the same objects
  NXArray *array = [NXArray arrayWithObjects:@"x", mutable, nil];
  NXArray *copied = [array copy];
  test_assert(copied != array && [copied zone] == zone);
  same(copied, array);
  test_assert([copied objectAtIndex:1] == mutable);
  test_assert([array appendObject:@"y"] && [copied count] == 2);
  test_assert([copied removeLastObject] && [array count] == 3);
  [copied release];
  copied = [[NXArray array] copy];
  test_assert(copied != nil && [copied count] == 0);
  [copied release];
}

test_main(0) {
  for (int i = 0; i < 3; i++) {
    NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
    hashes();
    copies(nil);
    [pool release];
  }

  // Objects which aren't in a zone are copied out of one, even once there's a
  // default zone
  NXMutableString *outside = [[NXMutableString alloc] initWithCString:"outside"];
  NXArray *outsideArray = [[NXArray alloc] initWithObjects:@"x", nil];
  test_assert([outside zone] == nil && [outsideArray zone] == nil);

  NXZone *zone = [NXZone zoneWithSize:8192];
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  copies(zone);
  NXString *outsideCopy = [outside copy];
  NXArray *outsideArrayCopy = [outsideArray copy];
  test_assert([outsideCopy zone] == nil && [outsideArrayCopy zone] == nil);
  test_assert([outsideCopy isEqual:outside] && [outsideArrayCopy isEqual:outsideArray]);
  [pool release];
  test_assert([zone count] == 0);
  [zone release];
  [outsideCopy release];
  [outsideArrayCopy release];
  [outside release];
  [outsideArray release];
}
