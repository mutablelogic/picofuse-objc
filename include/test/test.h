/**
 * @file test/test.h
 * @brief Macros for Objective-C tests.
 */
#pragma once
#include <picofuse/sys.h>
#include <runtime/gcc/objc.h>
#include <string.h>

/**
 * @def test_assert(condition)
 * @brief Asserts that a condition is true, panicking if it is not. Always
 * checked, regardless of NDEBUG. The condition can have commas in it, which aren't
 * otherwise allowed within brackets.
 */
#define test_assert(...)                                                       \
  do {                                                                         \
    if (!(__VA_ARGS__)) {                                                      \
      sys_panicf("[TEST] FAIL: %s, file %s, line %d", #__VA_ARGS__, __FILE__,  \
                 __LINE__);                                                    \
    }                                                                          \
  } while (0)

/**
 * @def test_assert_strequal(actual, expected)
 * @brief Asserts that two null-terminated strings are equal.
 */
#define test_assert_strequal(actual, expected)                                 \
  do {                                                                         \
    const char *_test_actual = (actual);                                       \
    const char *_test_expected = (expected);                                   \
    if (_test_actual == NULL || strcmp(_test_actual, _test_expected) != 0) {   \
      sys_panicf("[TEST] FAIL: expected \"%s\" but got \"%s\", file %s, "      \
                 "line %d",                                                    \
                 _test_expected, _test_actual, __FILE__, __LINE__);            \
    }                                                                          \
  } while (0)

/**
 * @def test_main(arena_size)
 * @brief Declares a test's entry point in place of main(), with the same
 * markers around the test body as picofuse's own tests.
 * @param arena_size Forwarded to sys_init().
 */
#define test_main(arena_size)                                                  \
  static void _test_main(void);                                                \
  int main(int argc, char *argv[]) {                                           \
    sys_init(argc, argv, (arena_size), sys_stdio_rtt);                         \
    sys_printf("[TEST] [INIT] %s\n", sys_env_name());                          \
    _test_main();                                                              \
    sys_printf("[TEST] [EXIT] %s\n", sys_env_name());                          \
    sys_exit();                                                                \
    return 0;                                                                  \
  }                                                                            \
  static void _test_main(void)
