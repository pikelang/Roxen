// -*- pike -*-
// Include file for use in test suites (start --self-test).
//
// Assumes:
//
// inherit "etc/test/tests/pike_test_common.pike"

// Run EXPR and check that it produces a nonzero result. If the test
// is logged then EXPR is printed. If ARGS is given then
// sprintf(EXPR, ARGS) is printed. Returns the result of EXPR.
#define TEST_TRUE(EXPR, ARGS...)                                        \
  cpp_test_true (__FILE__, __LINE__,                                    \
                 lambda() {return (EXPR);},                             \
                 #EXPR, ({ARGS}))

#define TEST_FALSE(EXPR, ARGS...)                                       \
  cpp_test_true (__FILE__, __LINE__,                                    \
                 lambda() {return !(EXPR);},                            \
                 #EXPR, ({ARGS}))

#define TEST_EQUAL(A, B)                                                \
  lambda () {                                                           \
    int len__ = min (max (sizeof (#A), sizeof (#B)), 40);               \
    array args__ = ({len__, #A, 0, len__, #B, 0});                      \
    return cpp_test_true (__FILE__, __LINE__,                           \
                   lambda() {                                           \
                     return equal (args__[2] = (A), args__[5] = (B));   \
                   },                                                   \
                   "%-*s  (is %O) equals\n"                             \
                   "%-*s  (is %O)?",                                    \
                   args__);                                             \
  }()

#define TEST_NOT_EQUAL(A, B)                                            \
  lambda () {                                                           \
    int len__ = min (max (sizeof (#A), sizeof (#B)), 40);               \
    array args__ = ({len__, #A, 0, len__, #B, 0});                      \
    return cpp_test_true (__FILE__, __LINE__,                           \
                   lambda() {                                           \
                     return !equal (args__[2] = (A), args__[5] = (B));  \
                   },                                                   \
                   "%-*s  (is %O) does not equal\n"                     \
                   "%-*s  (is %O)?",                                    \
                   args__);                                             \
  }()

#define TEST_CMP(A, OP, B)                                              \
  lambda () {                                                           \
    int len__ = min (max (sizeof (#A), sizeof (#B)), 40);               \
    array args__ = ({len__, #A, 0, len__, #B, 0});                      \
    return cpp_test_true (__FILE__, __LINE__,                           \
                   lambda() {                                           \
                     return (args__[2] = (A)) OP (args__[5] = (B));     \
                   },                                                   \
                   "%-*s  (is %O) " #OP "\n"                            \
                   "%-*s  (is %O)?",                                    \
                   args__);                                             \
  }()

#define TEST_ERROR(CODE, ARGS...)                                       \
  cpp_test_true (__FILE__, __LINE__,                                    \
                 lambda() {return catch {CODE;};},                      \
                 #CODE, ({ARGS}))

#define TEST_NOT_ERROR(CODE, ARGS...)                                   \
  cpp_test_true (__FILE__, __LINE__,                                    \
                 lambda() {return !catch {CODE;};},                     \
                 #CODE, ({ARGS}))

#define TEST_CALL(FN, ARGS...)                                          \
  test (({__FILE__, __LINE__, (FN)}), ARGS)
#define TEST_CALL_TRUE(FN, ARGS...)                                     \
  test_true (({__FILE__, __LINE__, (FN)}), ARGS)
#define TEST_CALL_FALSE(FN, ARGS...)                                    \
  test_false (({__FILE__, __LINE__, (FN)}), ARGS)
#define TEST_CALL_ERROR(FN, ARGS...)                                    \
  test_error (({__FILE__, __LINE__, (FN)}), ARGS)
#define TEST_CALL_EQUAL(VAL, FN, ARGS...)                               \
  test_equal ((VAL), ({__FILE__, __LINE__, (FN)}), ARGS)
#define TEST_CALL_NOT_EQUAL(VAL, FN, ARGS...)                           \
  test_not_equal ((VAL), ({__FILE__, __LINE__, (FN)}), ARGS)
#define TEST_CALL_GENERIC(CHECK_FN, FN, ARGS...)                        \
  test_generic ((CHECK_FN), ({__FILE__, __LINE__, (FN)}), ARGS)
