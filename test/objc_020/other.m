#include "shared.h"

@implementation Other
+ (Protocol *)protocol {
  return @protocol(Shared);
}
- (int)shared {
  return 1;
}
@end
