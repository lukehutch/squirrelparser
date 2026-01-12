# ===========================================================================
# SECTION 8: FIRST (ORDERED CHOICE) (8 tests)
# ===========================================================================

from tests.test_utils import run_test_parse


def test_fr01_match_1st():
    result = run_test_parse(
        'S <- "abc" / "ab" / "a" ;',
        'abc'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_fr02_match_2nd():
    result = run_test_parse(
        'S <- "xyz" / "abc" ;',
        'abc'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_fr03_match_3rd():
    result = run_test_parse(
        'S <- "x" / "y" / "z" ;',
        'z'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_fr04_with_recovery():
    result = run_test_parse(
        'S <- "x"+ "!" / "fallback" ;',
        'xZx!'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert 'Z' in result.skipped_strings, "should skip Z"


def test_fr05_fallback():
    result = run_test_parse(
        'S <- "a" "b" / "x" ;',
        'x'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_fr06_none_match():
    result = run_test_parse(
        'S <- "a" / "b" / "c" ;',
        'x'
    )
    assert not result.ok, "should fail"


def test_fr07_nested():
    result = run_test_parse(
        'S <- ("a" / "b") / "c" ;',
        'b'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_fr08_deep_nested():
    result = run_test_parse(
        'S <- (("a")) ;',
        'a'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"
