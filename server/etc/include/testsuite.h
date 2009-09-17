// -*- pike -*-
// Include file for use in test suites (start --self-test).
//
// Assumes:
//
// inherit "etc/test/tests/pike_test_common.pike"

// Run CODE and check that it produces a nonzero result. If the test
// is logged then CODE is printed. If ARGS is given then
// sprintf(CODE, ARGS) is printed. Returns the result of CODE.
#define TEST_TRUE(CODE, ARGS...)					\
  cpp_test_true (__FILE__, __LINE__, lambda() {return (CODE);}, #CODE, ({ARGS}))

#define TEST_EQUAL(A, B)						\
  do {									\
    /* NB: The evaluation is outside the time measurement. */		\
    mixed a__ = (A), b__ = (B);						\
    cpp_test_true (__FILE__, __LINE__,					\
		   lambda() {return equal (a__, b__);},			\
		   "%-40s  (is %O) equals\n"				\
		   "%-40s  (is %O)?",					\
		   ({#A, a__, #B, b__}));				\
  } while (0)

#define TEST_NOT_EQUAL(A, B)						\
  do {									\
    /* NB: The evaluation is outside the time measurement. */		\
    mixed a__ = (A), b__ = (B);						\
    cpp_test_true (__FILE__, __LINE__,					\
		   lambda() {return !equal (a__, b__);},		\
		   "%-40s  (is %O) does not equal\n"			\
		   "%-40s  (is %O)?",					\
		   ({#A, a__, #B, b__}));				\
  } while (0)

#define TEST_CALL(FN, ARGS...)						\
  test (({__FILE__, __LINE__, FN}), ARGS)
#define TEST_CALL_TRUE(FN, ARGS...)					\
  test_true (({__FILE__, __LINE__, FN}), ARGS)
#define TEST_CALL_FALSE(FN, ARGS...)					\
  test_false (({__FILE__, __LINE__, FN}), ARGS)
#define TEST_CALL_ERROR(FN, ARGS...)					\
  test_error (({__FILE__, __LINE__, FN}), ARGS)
#define TEST_CALL_EQUAL(VAL, FN, ARGS...)				\
  test_equal (VAL, ({__FILE__, __LINE__, FN}), ARGS)
#define TEST_CALL_NOT_EQUAL(VAL, FN, ARGS...)				\
  test_not_equal (VAL, ({__FILE__, __LINE__, FN}), ARGS)
