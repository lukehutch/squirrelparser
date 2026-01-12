# ===========================================================================
# SECTION 5: FIX #5/#6 - OPTIONAL AND EOF (25 tests)
# ===========================================================================

from tests.test_utils import test_parse, count_deletions
from squirrelparser.squirrel_parse import squirrel_parse_pt

# Mutual recursion grammar
MR_GRAMMAR = '''
    S <- A ;
    A <- "a" B / "y" ;
    B <- "b" A / "x" ;
'''


def test_F5_01_aby():
    result = test_parse(MR_GRAMMAR, 'aby')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_F5_02_abZy():
    result = test_parse(MR_GRAMMAR, 'abZy')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F5_03_ababy():
    result = test_parse(MR_GRAMMAR, 'ababy')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_F5_04_ax():
    result = test_parse(MR_GRAMMAR, 'ax')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_F5_05_y():
    result = test_parse(MR_GRAMMAR, 'y')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_F5_06_abx():
    # 'abx' is NOT in the language: after 'ab' we need A which requires 'a' or 'y', not 'x'
    # Grammar produces: y, ax, aby, abax, ababy, etc.
    # So this requires error recovery (skip 'b' and match 'ax', or skip 'bx' and fail)
    result = test_parse(MR_GRAMMAR, 'abx')
    assert result.ok, "should succeed with recovery"
    assert result.error_count >= 1, "should have at least 1 error"


def test_F5_06b_abax():
    # 'abax' IS in the language: A -> a B -> a b A -> a b a B -> a b a x
    result = test_parse(MR_GRAMMAR, 'abax')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_F5_07_ababx():
    # 'ababx' is NOT in the language: after 'abab' we need A which requires 'a' or 'y', not 'x'
    # Grammar produces: y, ax, aby, abax, ababy, ababax, abababy, etc.
    # So this requires error recovery
    result = test_parse(MR_GRAMMAR, 'ababx')
    assert result.ok, "should succeed with recovery"
    assert result.error_count >= 1, "should have at least 1 error"


def test_F5_07b_ababax():
    # 'ababax' IS in the language: A -> a B -> a b A -> a b a B -> a b a b A -> a b a b a B -> a b a b a x
    result = test_parse(MR_GRAMMAR, 'ababax')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_F6_01_Optional_wrapper():
    result = test_parse('S <- ("x"+ "!")? ;', 'xZx!')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F6_02_Optional_at_EOF():
    result = test_parse('S <- "x"? ;', '')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_F6_03_Nested_optional():
    result = test_parse('S <- (("x"+ "!")?)? ;', 'xZx!')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F6_04_Optional_in_Seq():
    result = test_parse('S <- ("x"+)? "!" ;', 'xZx!')
    assert result.ok, "should succeed"
    assert result.error_count == 1, "should have 1 error"
    assert any('Z' in s for s in result.skipped_strings), "should skip Z"


def test_F6_05_EOF_del_ok():
    parse_result = squirrel_parse_pt(
        grammar_spec='S <- "a" "b" "c" ;',
        top_rule_name='S',
        input='ab',
    )
    root = parse_result.root
    assert not root.is_mismatch, "should succeed with recovery"
    assert count_deletions([root]) == 1, "should have 1 deletion"
