# ===========================================================================
# SECTION 6: REPETITION COMPREHENSIVE (20 tests)
# ===========================================================================

from tests.test_utils import run_test_parse


def test_r01_between():
    result = run_test_parse('S <- "ab"+ ;', 'abXXab')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert 'XX' in result.skipped_strings, "should skip XX"


def test_r02_multi():
    result = run_test_parse('S <- "ab"+ ;', 'abXabYab')
    assert result.ok, "should succeed"
    assert result.error_count == 2, "should have 2 errors"
    assert 'X' in result.skipped_strings and 'Y' in result.skipped_strings, "should skip X and Y"


def test_r03_long_skip():
    result = run_test_parse('S <- "ab"+ ;', 'ab' + 'X' * 50 + 'ab')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"


def test_r04_zero_or_more_start():
    result = run_test_parse('S <- "ab"* "!" ;', 'XXab!')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert 'XX' in result.skipped_strings, "should skip XX"


def test_r05_before_first():
    # FIX #10: OneOrMore now allows first-iteration recovery
    result = run_test_parse('S <- "ab"+ ;', 'XXab')
    assert result.ok, "should succeed (skip XX on first iteration)"
    assert result.error_count == 1, "should have 1 error"
    assert 'XX' in result.skipped_strings, "should skip XX"


def test_r06_trailing_captured():
    # With new invariant, trailing errors are captured in parse tree
    result = run_test_parse('S <- "ab"+ ;', 'ababXX')
    assert result.ok, "should succeed with trailing captured"
    assert result.error_count == 1, "should have 1 error (trailing XX)"
    assert 'XX' in result.skipped_strings, "should skip XX"


def test_r07_single():
    result = run_test_parse('S <- "ab"+ ;', 'ab')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_r08_zero_or_more_empty():
    result = run_test_parse('S <- "ab"* ;', '')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_r09_alternating():
    result = run_test_parse('S <- "ab"+ ;', 'abXabXabXab')
    assert result.ok, "should succeed"
    assert result.error_count == 3, "should have 3 errors"


def test_r10_long_clean():
    result = run_test_parse('S <- "x"+ ;', 'x' * 100)
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_r11_long_err():
    result = run_test_parse('S <- "x"+ ;', 'x' * 50 + 'Z' + 'x' * 49)
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert 'Z' in result.skipped_strings, "should skip Z"


def test_r12_20_errors():
    input_str = ''.join(['abZ'] * 20) + 'ab'
    result = run_test_parse('S <- "ab"+ ;', input_str)
    assert result.ok, "should succeed"
    assert result.error_count == 20, "should have 20 errors"


def test_r13_very_long():
    result = run_test_parse('S <- "ab"+ ;', 'ab' * 500)
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_r14_very_long_err():
    result = run_test_parse('S <- "ab"+ ;', 'ab' * 250 + 'ZZ' + 'ab' * 249)
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"


# Tests for trailing error recovery (Issue: abxbxax failing completely)
# These tests ensure that after recovering from errors in the middle,
# the parser also captures trailing unmatched input as errors.

def test_r15_trailing_single_char_after_recovery():
    # After recovering from middle errors, trailing 'x' should also be caught as error
    result = run_test_parse('''
      S <- A ;
      A <- ("a" / "b")+ ;
    ''', 'abxbxax')
    assert result.ok, "should succeed with recovery"
    assert result.error_count == 3, "should have 3 errors (x at positions 2, 4, 6)"
    assert len(result.skipped_strings) == 3, "should skip 3 chars total"


def test_r16_trailing_multiple_chars_after_recovery():
    # Multiple trailing errors after recovery
    result = run_test_parse('S <- "ab"+ ;', 'abXabXabXX')
    assert result.ok, "should succeed with recovery"
    assert result.error_count == 3, "should have 3 errors"
    assert len(result.skipped_strings) == 3, "should skip 3 occurrences"


def test_r17_trailing_long_error_after_recovery():
    # Long trailing error after recovery
    result = run_test_parse('S <- "x"+ ;', 'x' * 50 + 'Z' + 'x' * 49 + 'YYYY')
    assert result.ok, "should succeed with recovery"
    assert result.error_count == 2, "should have 2 errors (Z and YYYY)"


def test_r18_trailing_after_multiple_alternating_errors():
    # Multiple errors throughout, then trailing error
    result = run_test_parse('S <- "ab"+ ;', 'abXabYabZabXX')
    assert result.ok, "should succeed with recovery"
    assert result.error_count == 4, "should have 4 errors (X, Y, Z, XX)"


def test_r19_single_char_after_first_recovery():
    # Recovery on first iteration, then trailing error
    result = run_test_parse('S <- "ab"+ ;', 'XXabX')
    assert result.ok, "should succeed"
    assert result.error_count == 2, "should have 2 errors (XX and X)"
    assert 'XX' in result.skipped_strings and 'X' in result.skipped_strings, \
        "should skip both XX and X"


def test_r20_trailing_error_with_single_element():
    # Single valid element followed by recovery, then trailing
    result = run_test_parse('S <- "a"+ ;', 'aXaY')
    assert result.ok, "should succeed"
    assert result.error_count == 2, "should have 2 errors (X and Y)"
