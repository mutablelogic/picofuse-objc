#include <test/test.h>

// A class with eight methods, and a category of it with two more
#define CLASS(n)                                                               \
  @interface C##n : Object                                                     \
  +(int)m0;                                                                    \
  +(int)m1;                                                                    \
  +(int)m2;                                                                    \
  +(int)m3;                                                                    \
  +(int)m4;                                                                    \
  +(int)m5;                                                                    \
  +(int)m6;                                                                    \
  +(int)m7;                                                                    \
  @end                                                                         \
  @implementation C##n                                                         \
  +(int)m0 {                                                                   \
    return n * 10;                                                             \
  }                                                                            \
  +(int)m1 {                                                                   \
    return n * 10 + 1;                                                         \
  }                                                                            \
  +(int)m2 {                                                                   \
    return n * 10 + 2;                                                         \
  }                                                                            \
  +(int)m3 {                                                                   \
    return n * 10 + 3;                                                         \
  }                                                                            \
  +(int)m4 {                                                                   \
    return n * 10 + 4;                                                         \
  }                                                                            \
  +(int)m5 {                                                                   \
    return n * 10 + 5;                                                         \
  }                                                                            \
  +(int)m6 {                                                                   \
    return n * 10 + 6;                                                         \
  }                                                                            \
  +(int)m7 {                                                                   \
    return n * 10 + 7;                                                         \
  }                                                                            \
  @end                                                                         \
  @interface C##n (More)                                                       \
  +(int)m8;                                                                    \
  +(int)m9;                                                                    \
  @end                                                                         \
  @implementation C##n (More)                                                  \
  +(int)m8 {                                                                   \
    return n * 10 + 8;                                                         \
  }                                                                            \
  +(int)m9 {                                                                   \
    return n * 10 + 9;                                                         \
  }                                                                            \
  @end

#define CHECK(n)                                                               \
  test_assert([C##n m0] == n * 10);                                            \
  test_assert([C##n m1] == n * 10 + 1);                                        \
  test_assert([C##n m2] == n * 10 + 2);                                        \
  test_assert([C##n m3] == n * 10 + 3);                                        \
  test_assert([C##n m4] == n * 10 + 4);                                        \
  test_assert([C##n m5] == n * 10 + 5);                                        \
  test_assert([C##n m6] == n * 10 + 6);                                        \
  test_assert([C##n m7] == n * 10 + 7);                                        \
  test_assert([C##n m8] == n * 10 + 8);                                        \
  test_assert([C##n m9] == n * 10 + 9);

// Fifty classes, which makes five hundred methods
#define TEN(X, n)                                                              \
  X(n##0) X(n##1) X(n##2) X(n##3) X(n##4)                                      \
  X(n##5) X(n##6) X(n##7) X(n##8) X(n##9)
#define FIFTY(X) TEN(X, 1) TEN(X, 2) TEN(X, 3) TEN(X, 4) TEN(X, 5)

FIFTY(CLASS)

test_main(0) {
  // Twice, so that what was found first isn't lost when the rest are added
  for (int i = 0; i < 2; i++) {
    FIFTY(CHECK)
  }

  // Methods which don't exist aren't found
  test_assert(!class_metaclassRespondsToSelector([C10 class], @selector(cStr)));
  test_assert(!class_respondsToSelector([C10 class], @selector(m0)));
}
