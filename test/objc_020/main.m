#include "shared.h"
#include <test/test.h>

@interface Here : Object <Shared>
@end

@implementation Here
- (int)shared {
  return 2;
}
@end

test_main(0) {
  // Each module has its own copy of the protocol, and either can be used
  Protocol *here = @protocol(Shared);
  Protocol *other = [Other protocol];
  test_assert_strequal([here name], "Shared");
  test_assert_strequal([other name], "Shared");
  test_assert([here isEqual:other] && [other isEqual:here]);
  test_assert([here conformsTo:other] && [other conformsTo:here]);
  test_assert([Here conformsTo:other] && [Other conformsTo:here]);
}
