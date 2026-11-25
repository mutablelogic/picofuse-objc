#include <test/TestObject.h>
#include <test/test.h>

typedef enum { red, green, blue } colour_t;

typedef struct {
  colour_t front : 3;
  colour_t back : 3;
} colours_t;

@class Unseen;

@interface Card : TestObject {
  unsigned _flag : 1;
  colour_t _colour : 3;
  colours_t _pair;
  colours_t *_pointer;
  Unseen *_unseen;
}
- (void)setFlag:(unsigned)flag colour:(colour_t)colour;
- (unsigned)flag;
- (colour_t)colour;
- (void)setPair:(colours_t)pair pointer:(colours_t *)pointer;
- (colours_t)pair;
- (colours_t *)pointer;
- (Unseen *)unseen;
@end

@implementation Card
- (void)setFlag:(unsigned)flag colour:(colour_t)colour {
  _flag = flag;
  _colour = colour;
}
- (unsigned)flag {
  return _flag;
}
- (colour_t)colour {
  return _colour;
}
- (void)setPair:(colours_t)pair pointer:(colours_t *)pointer {
  _pair = pair;
  _pointer = pointer;
}
- (colours_t)pair {
  return _pair;
}
- (colours_t *)pointer {
  return _pointer;
}
- (Unseen *)unseen {
  return _unseen;
}
@end

test_main(0) {
  Card *card = [[Card alloc] init];
  test_assert([card colour] == red && [card flag] == 0);

  [card setFlag:1 colour:blue];
  test_assert([card colour] == blue && [card flag] == 1);
  [card setFlag:0 colour:green];
  test_assert([card colour] == green && [card flag] == 0);

  colours_t pair = {.front = blue, .back = green};
  [card setPair:pair pointer:&pair];
  test_assert([card pair].front == blue && [card pair].back == green);
  test_assert([card pointer] == &pair);
  test_assert([card colour] == green);
  test_assert([card unseen] == nil);
  [card free];
}
