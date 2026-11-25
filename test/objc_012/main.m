#include <test/test.h>

test_main(0) {
  // Whether char is signed depends on the processor
  test_assert_strequal(@encode(char), (char)-1 < 0 ? "c" : "C");
  test_assert_strequal(@encode(signed char), "c");
  test_assert_strequal(@encode(unsigned char), "C");
  test_assert_strequal(@encode(short), "s");
  test_assert_strequal(@encode(unsigned short), "S");
  test_assert_strequal(@encode(int), "i");
  test_assert_strequal(@encode(unsigned int), "I");
  test_assert_strequal(@encode(long long), "q");
  test_assert_strequal(@encode(unsigned long long), "Q");
  test_assert_strequal(@encode(float), "f");
  test_assert_strequal(@encode(double), "d");
  test_assert_strequal(@encode(BOOL), "B");
  test_assert_strequal(@encode(void), "v");
  test_assert_strequal(@encode(char *), "*");
  test_assert_strequal(@encode(void *), "^v");
  test_assert_strequal(@encode(id), "@");
  test_assert_strequal(@encode(Object *), "@");
  test_assert_strequal(@encode(SEL), ":");

  // long is encoded by its size
#ifdef __LP64__
  test_assert_strequal(@encode(long), "q");
  test_assert_strequal(@encode(unsigned long), "Q");
#else
  test_assert_strequal(@encode(long), "l");
  test_assert_strequal(@encode(unsigned long), "L");
#endif
}
