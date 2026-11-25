#include <test/TestObject.h>
#include <test/test.h>

@protocol Switching
- (BOOL)isOn;
- (void)setOn:(BOOL)on;
@end

@protocol Weighing
- (int)weight;
@end

@interface Kettle : TestObject <Switching, Weighing> {
  BOOL _on;
}
@end

@implementation Kettle
- (BOOL)isOn {
  return _on;
}
- (void)setOn:(BOOL)on {
  _on = on;
}
- (int)weight {
  return 1200;
}
@end

@interface SmallKettle : Kettle
@end
@implementation SmallKettle
@end

test_main(0) {
  Kettle *kettle = [[Kettle alloc] init];
  id<Switching, Weighing> object = kettle;
  test_assert(![object isOn]);
  [object setOn:YES];
  test_assert([object isOn]);
  test_assert([object weight] == 1200);

  test_assert([kettle conformsTo:@protocol(Switching)]);
  test_assert([kettle conformsTo:@protocol(Weighing)]);
  test_assert([Kettle conformsTo:@protocol(Switching)]);
  test_assert([Kettle conformsTo:@protocol(Weighing)]);
  test_assert([SmallKettle conformsTo:@protocol(Weighing)]);
  test_assert(![TestObject conformsTo:@protocol(Weighing)]);
  [kettle free];
}
