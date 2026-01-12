# ===========================================================================
# FIRST ALTERNATIVE SELECTION TESTS (FIX #2 Verification)
# ===========================================================================
# These tests verify that First correctly selects alternatives based on
# length priority (longer matches preferred) with error count as tiebreaker.

from tests.test_utils import test_parse


class TestFirstAlternativeSelection:

    def test_first01_all_alternatives_fail_cleanly(self):
        # All alternatives mismatch, no recovery possible
        result = test_parse('S <- "a" / "b" / "c" ;', 'x')
        assert result.ok is False, "should fail (no alternative matches)"

    def test_first02_first_needs_recovery_second_clean(self):
        # FIX #2: Prefer longer matches, so first alternative wins despite error
        result = test_parse('S <- "a" "b" / "c" ;', 'aXb')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "first alternative chosen (longer despite error)"

    def test_first03_all_alternatives_need_recovery(self):
        # Multiple alternatives with recovery, choose best
        result = test_parse('S <- "a" "b" "c" / "a" "y" "z" ;', 'aXbc')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should choose first alternative (matches with recovery)"

    def test_first04_longer_with_error_vs_shorter_clean(self):
        # FIX #2: Length priority - longer wins even with error
        result = test_parse('S <- "a" "b" "c" / "a" ;', 'aXbc')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should choose first (longer despite error)"

    def test_first05_same_length_fewer_errors_wins(self):
        # Same length, fewer errors wins
        result = test_parse('S <- "a" "b" "c" "d" / "a" "b" "c" ;', 'aXbc')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should choose second (fewer errors)"

    def test_first06_multiple_clean_alternatives(self):
        # Multiple alternatives match cleanly, first wins
        result = test_parse('S <- "abc" / "abc" / "ab" ;', 'abc')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors (clean match)"
        # First alternative wins

    def test_first07_prefer_longer_clean_over_shorter_clean(self):
        # Two clean alternatives, different lengths
        result = test_parse('S <- "abc" / "ab" ;', 'abc')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # First matches full input (len=3), second would match len=2
        # But First tries in order, so first wins anyway

    def test_first08_fallback_after_all_longer_fail(self):
        # Longer alternatives fail, shorter succeeds
        result = test_parse('S <- "x" "y" "z" / "a" ;', 'a')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors (clean second alternative)"

    def test_first09_left_recursive_alternative(self):
        # First contains left-recursive alternative
        result = test_parse('E <- E "+" "n" / "n" ;', 'n+Xn', 'E')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        # LR expansion with recovery

    def test_first10_nested_first(self):
        # First containing another First
        result = test_parse('S <- ("a" / "b") / "c" ;', 'b')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # Outer First tries first alternative (inner First), which matches 'b'

    def test_first11_all_alternatives_incomplete(self):
        # All alternatives incomplete (don't consume full input)
        # With new invariant, best match selected, trailing captured
        result = test_parse('S <- "a" / "b" ;', 'aXXX')
        assert result.ok is True, "should succeed with trailing captured"
        assert result.error_count == 1, "should have 1 error (trailing XXX)"
        assert 'XXX' in result.skipped_strings, "should capture XXX"

    def test_first12_recovery_with_complex_alternatives(self):
        # Complex alternatives with nested structures
        result = test_parse('S <- "x"+ "y" / "a"+ "b" ;', 'xxxXy')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should choose first alternative"
