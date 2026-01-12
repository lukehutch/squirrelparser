# ===========================================================================
# SECTION 7: SEQUENCE COMPREHENSIVE (10 tests)
# ===========================================================================

from tests.test_utils import run_test_parse, count_deletions
from squirrelparser import squirrel_parse_pt, SyntaxError


def test_s01_2_elem():
    result = run_test_parse(
        'S <- "a" "b" ;',
        'ab'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_s02_3_elem():
    result = run_test_parse(
        'S <- "a" "b" "c" ;',
        'abc'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_s03_5_elem():
    result = run_test_parse(
        'S <- "a" "b" "c" "d" "e" ;',
        'abcde'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_s04_insert_mid():
    result = run_test_parse(
        'S <- "a" "b" "c" ;',
        'aXXbc'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert 'XX' in result.skipped_strings, "should skip XX"


def test_s05_insert_end():
    result = run_test_parse(
        'S <- "a" "b" "c" ;',
        'abXXc'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert 'XX' in result.skipped_strings, "should skip XX"


def test_s06_del_mid():
    # Cannot delete grammar elements mid-parse (Fix #8 - Visibility Constraint)
    # Input "ac" with grammar "a" "b" "c" would require deleting "b" at position 1
    # Position 1 is not EOF (still have "c" to parse), so this violates constraints
    parse_result = squirrel_parse_pt(
        grammar_spec='S <- "a" "b" "c" ;',
        top_rule_name='S',
        input='ac',
    )
    result = parse_result.root
    # Should fail - cannot delete "b" mid-parse
    # Total failure: result is SyntaxError spanning entire input
    assert isinstance(result, SyntaxError), \
        "should fail (mid-parse grammar deletion violates Visibility Constraint)"


def test_s07_del_end():
    parse_result = squirrel_parse_pt(
        grammar_spec='S <- "a" "b" "c" ;',
        top_rule_name='S',
        input='ab',
    )
    result = parse_result.root
    assert not result.is_mismatch, "should succeed"
    assert count_deletions([result]) == 1, "should have 1 deletion"


def test_s08_nested_clean():
    result = run_test_parse(
        'S <- ("a" "b") "c" ;',
        'abc'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_s09_nested_insert():
    result = run_test_parse(
        'S <- ("a" "b") "c" ;',
        'aXbc'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert 'X' in result.skipped_strings, "should skip X"


def test_s10_long_seq_clean():
    result = run_test_parse(
        'S <- "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" ;',
        'abcdefghijklmnop'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"
