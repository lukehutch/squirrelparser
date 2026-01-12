# ===========================================================================
# SECTION 4: FIX #4 - MULTI-LEVEL BOUNDED RECOVERY (35 tests)
# ===========================================================================

from tests.test_utils import test_parse


def test_F4_L1_01_clean_2():
    result = test_parse('S <- ("(" "x"+ ")")+ ;', '(xx)(xx)')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_F4_L1_02_clean_5():
    result = test_parse('S <- ("(" "x"+ ")")+ ;', '(xx)' * 5)
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_F4_L1_03_err_first():
    result = test_parse('S <- ("(" "x"+ ")")+ ;', '(xZx)(xx)')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F4_L1_04_err_mid():
    result = test_parse('S <- ("(" "x"+ ")")+ ;', '(xx)(xZx)(xx)')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F4_L1_05_err_last():
    result = test_parse('S <- ("(" "x"+ ")")+ ;', '(xx)(xZx)')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F4_L1_06_err_all_3():
    result = test_parse('S <- ("(" "x"+ ")")+ ;', '(xAx)(xBx)(xCx)')
    assert result.ok, "should succeed"
    assert result.error_count == 3, "should have 3 errors"
    assert (any('A' in s for s in result.skipped_strings) and
            any('B' in s for s in result.skipped_strings) and
            any('C' in s for s in result.skipped_strings)), "should skip A, B, C"


def test_F4_L1_07_boundary():
    result = test_parse('S <- ("(" "x"+ ")")+ ;', '(xx)Z(xx)')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F4_L1_08_long_boundary():
    result = test_parse('S <- ("(" "x"+ ")")+ ;', '(xx)ZZZ(xx)')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('ZZZ' in s for s in result.skipped_strings), "should skip ZZZ"


def test_F4_L2_01_clean():
    result = test_parse('S <- "{" ("(" "x"+ ")")+ "}" ;', '{(xx)(xx)}')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_F4_L2_02_err_inner():
    result = test_parse('S <- "{" ("(" "x"+ ")")+ "}" ;', '{(xx)(xZx)}')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F4_L2_03_err_outer():
    result = test_parse('S <- "{" ("(" "x"+ ")")+ "}" ;', '{(xx)Z(xx)}')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F4_L2_04_both_levels():
    result = test_parse('S <- "{" ("(" "x"+ ")")+ "}" ;', '{(xAx)B(xCx)}')
    assert result.ok, "should succeed"
    assert result.error_count == 3, "should have 3 errors"


def test_F4_L3_01_clean():
    result = test_parse('S <- "[" "{" ("(" "x"+ ")")+ "}" "]" ;', '[{(xx)(xx)}]')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_F4_L3_02_err_deepest():
    result = test_parse('S <- "[" "{" ("(" "x"+ ")")+ "}" "]" ;', '[{(xx)(xZx)}]')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F4_N1_10_groups():
    result = test_parse('S <- ("(" "x"+ ")")+ ;', '(xx)' * 10)
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_F4_N2_10_groups_5_err():
    input_str = ''.join('(xZx)' if i % 2 == 0 else '(xx)' for i in range(10))
    result = test_parse('S <- ("(" "x"+ ")")+ ;', input_str)
    assert result.ok, "should succeed"
    assert result.error_count == 5, "should have 5 errors"


def test_F4_N3_20_groups():
    result = test_parse('S <- ("(" "x"+ ")")+ ;', '(xx)' * 20)
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"
