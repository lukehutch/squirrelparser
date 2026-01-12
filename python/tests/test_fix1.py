# ===========================================================================
# SECTION 2: FIX #1 - isComplete PROPAGATION (25 tests)
# ===========================================================================

from tests.test_utils import test_parse


def test_F1_01_Rep_Seq_basic():
    result = test_parse('S <- "ab"+ "!" ;', 'abXXab!')
    assert result.ok, "should succeed"
    assert result.error_count == 1, f"should have 1 error, got {result.error_count}"
    assert any('XX' in s for s in result.skipped_strings), "should skip XX"


def test_F1_02_Rep_Optional():
    result = test_parse('S <- "ab"+ "!"? ;', 'abXXab')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('XX' in s for s in result.skipped_strings), "should skip XX"


def test_F1_03_Rep_Optional_match():
    result = test_parse('S <- "ab"+ "!"? ;', 'abXXab!')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('XX' in s for s in result.skipped_strings), "should skip XX"


def test_F1_04_First_wrapping():
    result = test_parse('S <- ("ab"+ "!") ;', 'abXXab!')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"


def test_F1_05_Nested_Seq_L1():
    result = test_parse('S <- (("x"+)) ;', 'xZx')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F1_06_Nested_Seq_L2():
    result = test_parse('S <- ((("x"+))) ;', 'xZx')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F1_07_Nested_Seq_L3():
    result = test_parse('S <- (((("x"+)))) ;', 'xZx')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F1_08_Optional_wrapping():
    result = test_parse('S <- (("x"+))? ;', 'xZx')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F1_09_ZeroOrMore_in_Seq():
    result = test_parse('S <- "ab"* "!" ;', 'abXXab!')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('XX' in s for s in result.skipped_strings), "should skip XX"


def test_F1_10_Multiple_Reps():
    result = test_parse('S <- "a"+ "b"+ ;', 'aXabYb')
    assert result.ok, "should succeed"
    assert result.error_count == 2, "should have 2 errors"


def test_F1_11_Rep_Rep_Term():
    result = test_parse('S <- "a"+ "b"+ "!" ;', 'aXabYb!')
    assert result.ok, "should succeed"
    assert result.error_count == 2, "should have 2 errors"


def test_F1_12_Long_error_span():
    result = test_parse('S <- "x"+ "!" ;', 'x' + 'Z' * 20 + 'x!')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"


def test_F1_13_Multiple_long_errors():
    result = test_parse('S <- "ab"+ ;', 'ab' + 'X' * 10 + 'ab' + 'Y' * 10 + 'ab')
    assert result.ok, "should succeed"
    assert result.error_count == 2, "should have 2 errors"


def test_F1_14_Interspersed_errors():
    result = test_parse('S <- "ab"+ ;', 'abXabYabZab')
    assert result.ok, "should succeed"
    assert result.error_count == 3, "should have 3 errors"


def test_F1_15_Five_errors():
    result = test_parse('S <- "ab"+ ;', 'abAabBabCabDabEab')
    assert result.ok, "should succeed"
    assert result.error_count == 5, "should have 5 errors"
