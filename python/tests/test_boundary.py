# ===========================================================================
# SECTION 1: EMPTY AND BOUNDARY CONDITIONS (27 tests)
# ===========================================================================

from squirrelparser import squirrel_parse_pt
from tests.test_utils import test_parse, count_deletions


class TestEmptyAndBoundaryConditions:

    def test_e01_zero_or_more_empty(self):
        result = test_parse('S <- "x"* ;', '')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e02_one_or_more_empty(self):
        result = test_parse('S <- "x"+ ;', '')
        assert result.ok is False, "should fail"

    def test_e03_optional_empty(self):
        result = test_parse('S <- "x"? ;', '')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e04_seq_empty_recovery(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a" "b" ;',
            top_rule_name='S',
            input='',
        )
        result = parse_result.root
        assert not result.is_mismatch, "should succeed with recovery"
        assert count_deletions([result]) == 2, "should have 2 deletions"

    def test_e05_first_empty(self):
        result = test_parse('S <- "a" / "b" ;', '')
        assert result.ok is False, "should fail"

    def test_e06_ref_empty(self):
        result = test_parse('S <- A ; A <- "x" ;', '')
        assert result.ok is False, "should fail"

    def test_e07_single_char_match(self):
        result = test_parse('S <- "x" ;', 'x')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e08_single_char_mismatch(self):
        result = test_parse('S <- "x" ;', 'y')
        assert result.ok is False, "should fail"

    def test_e09_zero_or_more_single(self):
        result = test_parse('S <- "x"* ;', 'x')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e10_one_or_more_single(self):
        result = test_parse('S <- "x"+ ;', 'x')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e11_optional_match(self):
        result = test_parse('S <- "x"? ;', 'x')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e12_two_chars_match(self):
        result = test_parse('S <- "xy" ;', 'xy')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e13_two_chars_partial(self):
        result = test_parse('S <- "xy" ;', 'x')
        assert result.ok is False, "should fail"

    def test_e14_char_range_match(self):
        result = test_parse('S <- [a-z] ;', 'm')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e15_char_range_boundary_low(self):
        result = test_parse('S <- [a-z] ;', 'a')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e16_char_range_boundary_high(self):
        result = test_parse('S <- [a-z] ;', 'z')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e17_char_range_fail_low(self):
        result = test_parse('S <- [b-y] ;', 'a')
        assert result.ok is False, "should fail"

    def test_e18_char_range_fail_high(self):
        result = test_parse('S <- [b-y] ;', 'z')
        assert result.ok is False, "should fail"

    def test_e19_any_char_match(self):
        result = test_parse('S <- . ;', 'x')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e20_any_char_empty(self):
        result = test_parse('S <- . ;', '')
        assert result.ok is False, "should fail"

    def test_e21_seq_single(self):
        result = test_parse('S <- ("x") ;', 'x')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e22_first_single(self):
        result = test_parse('S <- "x" ;', 'x')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e23_nested_empty(self):
        result = test_parse('S <- "a"? "b"? ;', '')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e24_zero_or_more_multi(self):
        result = test_parse('S <- "x"* ;', 'xxx')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e25_one_or_more_multi(self):
        result = test_parse('S <- "x"+ ;', 'xxx')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e26_long_string_match(self):
        result = test_parse('S <- "abcdefghij" ;', 'abcdefghij')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_e27_long_string_partial(self):
        result = test_parse('S <- "abcdefghij" ;', 'abcdefghi')
        assert result.ok is False, "should fail"
