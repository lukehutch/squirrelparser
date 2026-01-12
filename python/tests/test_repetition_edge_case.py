# ===========================================================================
# REPETITION EDGE CASE TESTS
# ===========================================================================
# These tests verify edge cases in repetition handling including nested
# repetitions, probe mechanics, and boundary interactions.

from tests.test_utils import test_parse


class TestRepetitionEdgeCase:

    def test_rep01_zeroormore_empty_match(self):
        # ZeroOrMore can match zero times
        result = test_parse('S <- "x"* "y" ;', 'y')
        assert result.ok is True, "should succeed (ZeroOrMore matches 0)"
        assert result.error_count == 0, "should have 0 errors"

    def test_rep02_oneormore_vs_zeroormore_at_eof(self):
        # OneOrMore requires at least one match, ZeroOrMore doesn't
        om = test_parse('S <- "x"+ ;', '')
        assert om.ok is False, "OneOrMore should fail on empty input"

        zm = test_parse('S <- "x"* ;', '')
        assert zm.ok is True, "ZeroOrMore should succeed on empty input"

    def test_rep03_nested_repetition(self):
        # OneOrMore(OneOrMore(x)) - nested repetitions
        result = test_parse('S <- ("x"+)+ ;', 'xxxXxxXxxx')
        assert result.ok is True, "should succeed"
        assert result.error_count == 2, "should have 2 errors (two X gaps)"
        # Outer: matches 3 times (group1, skip X, group2, skip X, group3)
        # Each group is inner OneOrMore matching x's

    def test_rep04_repetition_with_recovery_hits_bound(self):
        # Repetition with recovery, encounters bound
        result = test_parse('S <- "x"+ "end" ;', 'xXxXxend')
        assert result.ok is True, "should succeed"
        assert result.error_count == 2, "should have 2 errors"
        assert len(result.skipped_strings) == 2, "should skip 2 X's"
        # Repetition stops before 'end' (bound)

    def test_rep05_repetition_recovery_vs_probe(self):
        # ZeroOrMore must probe ahead to avoid consuming boundary
        result = test_parse('S <- "x"* "y" ;', 'xxxy')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # ZeroOrMore should match all x's, stop before 'y'

    def test_rep06_alternating_match_skip_pattern(self):
        # Pattern: match, skip, match, skip, ...
        result = test_parse('S <- "ab"+ ;', 'abXabXabXab')
        assert result.ok is True, "should succeed"
        assert result.error_count == 3, "should have 3 errors (3 X's)"

    def test_rep07_repetition_of_complex_structure(self):
        # OneOrMore(Seq([...])) - repetition of sequences
        result = test_parse('S <- ("a" "b")+ ;', 'ababab')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # Matches 3 times: (a,b), (a,b), (a,b)

    def test_rep08_repetition_stops_on_non_match(self):
        # Repetition stops when element no longer matches
        result = test_parse('S <- "x"+ "y" ;', 'xxxy')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # OneOrMore matches 3 x's, stops, then 'y' matches

    def test_rep09_repetition_with_first_alternative(self):
        # OneOrMore(First([...])) - repetition of alternatives
        result = test_parse('S <- ("a" / "b")+ ;', 'aabba')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # Matches 5 times: a, a, b, b, a

    def test_rep10_zeroormore_with_recovery_inside(self):
        # ZeroOrMore element needs recovery
        result = test_parse('S <- ("a" "b")* ;', 'abXaYb')
        assert result.ok is True, "should succeed"
        assert result.error_count == 2, "should have 2 errors"
        # First iteration: a, b (clean)
        # Second iteration: Seq needs recovery
        #   Within Seq: 'a' expects 'a' at pos 2, sees 'X', skip X, match 'a' at pos 3
        #   Then 'b' expects 'b' at pos 4, sees 'Y', skip Y, match 'b' at pos 5
        # So yes, 2 errors total

    def test_rep11_greedy_vs_non_greedy(self):
        # Repetitions are greedy - match as many as possible
        result = test_parse('S <- "x"* "y" "z" ;', 'xxxxxyz')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # ZeroOrMore is greedy, matches all x's, then y and z

    def test_rep12_repetition_at_eof_with_deletion(self):
        # Repetition at EOF can have grammar deletion (completion)
        result = test_parse('S <- "a" "b"+ ;', 'a')
        assert result.ok is True, "should succeed (delete b+ at EOF)"
        # At EOF, can delete the OneOrMore requirement

    def test_rep13_very_long_repetition(self):
        # Performance test: many iterations
        input_str = 'x' * 1000
        result = test_parse('S <- "x"+ ;', input_str)
        assert result.ok is True, "should succeed (1000 iterations)"
        assert result.error_count == 0, "should have 0 errors"

    def test_rep14_repetition_with_many_errors(self):
        # Many errors within repetition
        input_str = ''.join(['Xx' for _ in range(100)])
        result = test_parse('S <- "x"+ ;', input_str)
        assert result.ok is True, "should succeed"
        assert result.error_count == 100, "should have 100 errors"

    def test_rep15_nested_zeroormore(self):
        # ZeroOrMore(ZeroOrMore(...)) - both can match zero
        result = test_parse('S <- ("x"*)* "y" ;', 'y')
        assert result.ok is True, "should succeed (both match 0)"
        assert result.error_count == 0, "should have 0 errors"
