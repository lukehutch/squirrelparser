# ===========================================================================
# ONEORMORE FIRST-ITERATION RECOVERY TESTS (FIX #10 Verification)
# ===========================================================================
# These tests verify that OneOrMore allows recovery on the first iteration
# while still maintaining "at least one match" semantics.

from tests.test_utils import test_parse


class TestOneormoreRecovery:

    def test_om01_first_clean(self):
        # Baseline: First iteration succeeds cleanly
        result = test_parse('S <- "ab"+ ;', 'ababab')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_om02_no_match_anywhere(self):
        # OneOrMore still requires at least one match
        result = test_parse('S <- "ab"+ ;', 'xyz')
        assert result.ok is False, "should fail (no match found)"

    def test_om03_skip_to_first_match(self):
        # FIX #10: Skip garbage to find first match
        result = test_parse('S <- "ab"+ ;', 'Xab')
        assert result.ok is True, "should succeed (skip X on first iteration)"
        assert result.error_count == 1, "should have 1 error"
        assert 'X' in result.skipped_strings, "should skip X"

    def test_om04_skip_multiple_to_first(self):
        # FIX #10: Skip multiple characters to find first match
        result = test_parse('S <- "ab"+ ;', 'XXXXXab')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error (entire skip)"
        assert 'XXXXX' in result.skipped_strings, "should skip XXXXX"

    def test_om05_multiple_iterations_with_errors(self):
        # FIX #10: First iteration with error, then more iterations with errors
        result = test_parse('S <- "ab"+ ;', 'XabYabZab')
        assert result.ok is True, "should succeed"
        assert result.error_count == 3, "should have 3 errors"
        assert 'X' in result.skipped_strings, "should skip X"
        assert 'Y' in result.skipped_strings, "should skip Y"
        assert 'Z' in result.skipped_strings, "should skip Z"

    def test_om06_first_with_error_then_clean(self):
        # First iteration skips error, subsequent iterations clean
        result = test_parse('S <- "ab"+ ;', 'Xabababab')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error (only X)"
        assert 'X' in result.skipped_strings, "should skip X"

    def test_om07_vs_zeroormore_semantics(self):
        # BOTH ZeroOrMore and OneOrMore fail on input with no matches
        # because parseWithRecovery requires parsing the ENTIRE input.
        # ZeroOrMore matches 0 times (len=0), leaving "XYZ" unparsed.
        # OneOrMore matches 0 times (fails "at least one"), also leaving input unparsed.

        # Key difference: Empty input
        zr_empty = test_parse('S <- "ab"* ;', '')
        assert zr_empty.ok is True, "ZeroOrMore should succeed on empty input"
        assert zr_empty.error_count == 0, "should have 0 errors"

        or_empty = test_parse('S <- "ab"+ ;', '')
        assert or_empty.ok is False, "OneOrMore should fail on empty input"

        # Key difference: With valid matches
        zr_match = test_parse('S <- "ab"* ;', 'ababab')
        assert zr_match.ok is True, "ZeroOrMore succeeds with matches"

        or_match = test_parse('S <- "ab"+ ;', 'ababab')
        assert or_match.ok is True, "OneOrMore succeeds with matches"

    def test_om08_long_skip_performance(self):
        # Large skip distance should still complete quickly
        input_str = 'X' * 100 + 'ab'
        result = test_parse('S <- "ab"+ ;', input_str)
        assert result.ok is True, "should succeed (performance test)"
        assert result.error_count == 1, "should have 1 error"
        assert len(result.skipped_strings[0]) == 100, "should skip 100 X's"

    def test_om09_exhaustive_search_no_match(self):
        # Try all positions, find nothing, fail cleanly
        input_str = 'X' * 50 + 'Y' * 50  # No 'ab' anywhere
        result = test_parse('S <- "ab"+ ;', input_str)
        assert result.ok is False, "should fail (exhaustive search finds nothing)"

    def test_om10_first_iteration_with_bound(self):
        # First iteration recovery + bound checking
        result = test_parse('S <- "ab"+ "end" ;', 'XabYabend')
        assert result.ok is True, "should succeed"
        assert result.error_count == 2, "should have 2 errors (X and Y)"
        assert 'X' in result.skipped_strings, "should skip X"
        assert 'Y' in result.skipped_strings, "should skip Y"

    def test_om11_alternating_pattern(self):
        # Pattern: error, match, error, match, ...
        result = test_parse('S <- "ab"+ ;', 'XabXabXabXab')
        assert result.ok is True, "should succeed"
        assert result.error_count == 4, "should have 4 errors (4 X's)"

    def test_om12_multi_char_terminal_first(self):
        # Multi-character terminal with first-iteration recovery
        result = test_parse('S <- "hello"+ ;', 'XXXhellohello')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert 'XXX' in result.skipped_strings, "should skip XXX"
