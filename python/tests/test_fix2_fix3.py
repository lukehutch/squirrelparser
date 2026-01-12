# ===========================================================================
# SECTION 3: FIX #2/#3 - CACHE INTEGRITY (20 tests)
# ===========================================================================

from tests.test_utils import test_parse


def test_F2_01_Basic_probe():
    result = test_parse('S <- "(" "x"+ ")" ;', '(xZZx)')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('ZZ' in s for s in result.skipped_strings), "should skip ZZ"


def test_F2_02_Double_probe():
    result = test_parse('S <- "a" "x"+ "b" "y"+ "c" ;', 'axXxbyYyc')
    assert result.ok, "should succeed"
    assert result.error_count == 2, "should have 2 errors"


def test_F2_03_Probe_same_clause():
    result = test_parse('S <- ("(" "x"+ ")")+ ;', '(xZx)(xYx)')
    assert result.ok, "should succeed"
    assert result.error_count == 2, "should have 2 errors"
    assert any('Z' in s for s in result.skipped_strings) and any('Y' in s for s in result.skipped_strings), \
        "should skip Z and Y"


def test_F2_04_Triple_group():
    result = test_parse('S <- ("[" "x"+ "]")+ ;', '[xAx][xBx][xCx]')
    assert result.ok, "should succeed"
    assert result.error_count == 3, "should have 3 errors"


def test_F2_05_Five_groups():
    result = test_parse('S <- ("(" "x"+ ")")+ ;', '(xAx)(xBx)(xCx)(xDx)(xEx)')
    assert result.ok, "should succeed"
    assert result.error_count == 5, "should have 5 errors"


def test_F2_06_Alternating_clean_err():
    result = test_parse('S <- ("(" "x"+ ")")+ ;', '(xx)(xZx)(xx)(xYx)(xx)')
    assert result.ok, "should succeed"
    assert result.error_count == 2, "should have 2 errors"


def test_F2_07_Long_inner_error():
    result = test_parse('S <- "(" "x"+ ")" ;', '(x' + 'Z' * 20 + 'x)')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"


def test_F2_08_Nested_probe():
    result = test_parse('S <- "{" "(" "x"+ ")" "}" ;', '{(xZx)}')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F2_09_Triple_nested():
    result = test_parse('S <- "<" "{" "[" "x"+ "]" "}" ">" ;', '<{[xZx]}>')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F2_10_Ref_probe():
    result = test_parse('''
        S <- "(" R ")" ;
        R <- "x"+ ;
        ''', '(xZx)')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"
