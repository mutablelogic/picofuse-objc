#include <stdarg.h>
#include <test/test.h>

@interface Sums : Object
// The list ends with a negative number
+ (int)sum:(int)first, ...;
+ (double)scale:(double)value by:(int)times plus:(long long)offset;
+ (int)next;
+ (int)twice:(int)value;
@end

@implementation Sums

static int number = 40;

static int twice(int value) { return value * 2; }

+ (int)sum:(int)first, ... {
  int total = 0;
  va_list args;
  va_start(args, first);
  for (int value = first; value >= 0; value = va_arg(args, int)) {
    total += value;
  }
  va_end(args);
  return total;
}

+ (double)scale:(double)value by:(int)times plus:(long long)offset {
  return value * times + offset;
}

+ (int)next {
  return ++number;
}

+ (int)twice:(int)value {
  return twice(value);
}

@end

test_main(0) {
  int total = [Sums sum:-1];
  test_assert(total == 0);
  total = [Sums sum:7, -1];
  test_assert(total == 7);
  total = [Sums sum:1, 2, 3, 4, 5, 6, 7, 8, -1];
  test_assert(total == 36);

  test_assert([Sums scale:1.5 by:4 plus:10000000000LL] == 10000000006.0);
  test_assert([Sums next] == 41);
  test_assert([Sums next] == 42);
  test_assert([Sums twice:21] == 42);
}
