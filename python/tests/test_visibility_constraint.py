# ===========================================================================
# VISIBILITY CONSTRAINT TESTS (FIX #8 Verification)
# ===========================================================================
# These tests verify that parse trees match visible input structure and that
# grammar deletion (inserting missing elements) only occurs at EOF.

from squirrelparser import squirrel_parse_pt
from squirrelparser.match_result import SyntaxError
from tests.test_utils import test_parse, count_deletions


class TestVisibilityConstraint:

    def test_vis01_terminal_atomicity(self):
        # Multi-char terminals are atomic - can't skip through them
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "abc" "def" ;',
            top_rule_name='S',
            input='abXdef',
        )
        result = parse_result.root
        # Should fail - can't match 'abc' with 'abX', and can't skip 'X' mid-terminal
        # Total failure: result is a SyntaxError spanning entire input
        assert isinstance(result, SyntaxError), "should fail (cannot skip within multi-char terminal)"

    def test_vis02_grammar_deletion_at_eof(self):
        # Grammar deletion (completion) allowed at EOF
        result = test_parse('S <- "a" "b" "c" ;', 'ab')
        assert result.ok is True, "should succeed (delete c at EOF)"

        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a" "b" "c" ;',
            top_rule_name='S',
            input='ab',
        )
        assert count_deletions([parse_result.root]) == 1, "should have 1 deletion"

    def test_vis03_grammar_deletion_mid_parse_forbidden(self):
        # Grammar deletion NOT allowed mid-parse (FIX #8)
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a" "b" "c" ;',
            top_rule_name='S',
            input='ac',
        )
        result = parse_result.root
        # Should fail - cannot delete 'b' at position 1 (not EOF)
        # Total failure: result is a SyntaxError spanning entire input
        assert isinstance(result, SyntaxError), "should fail (mid-parse grammar deletion violates Visibility Constraint)"

    def test_vis04_tree_structure_matches_visible_input(self):
        # Parse tree structure should match visible input structure
        result = test_parse('S <- "a" "b" "c" ;', 'aXbc')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert 'X' in result.skipped_strings, "should skip X"
        # Visible input: a, X, b, c (4 elements)
        # Tree: a, SyntaxError(X), b, c (4 nodes)

    def test_vis05_hidden_deletion_creates_mismatch(self):
        # First tries alternatives; Seq needs 'b' but input is just 'a'
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a" "b" / "c" ;',
            top_rule_name='S',
            input='a',
        )
        result = parse_result.root
        # First alternative: Try Seq - 'a' matches, 'b' missing at EOF
        #   - Could delete 'b' at EOF, but that gives len=1
        # Second alternative: Try 'c' - fails (input is 'a')
        # Should pick first alternative with completion
        # Result always spans input, so check it's not a total failure
        assert not isinstance(result, SyntaxError), "should succeed (first alternative with EOF deletion)"
        # With new invariant, result.len == input.length always
        assert result.len == 1, "should consume 1 char (a)"

    def test_vis06_multiple_consecutive_skips(self):
        # Multiple consecutive errors should be merged into one region
        result = test_parse('S <- "a" "b" "c" ;', 'aXXXXbc')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error (entire XXXX region)"
        assert 'XXXX' in result.skipped_strings, "should skip XXXX as one region"

    def test_vis07_alternating_content_and_errors(self):
        # Pattern: valid, error, valid, error, valid, error, valid
        result = test_parse('S <- "a" "b" "c" "d" ;', 'aXbYcZd')
        assert result.ok is True, "should succeed"
        assert result.error_count == 3, "should have 3 errors"
        assert 'X' in result.skipped_strings, "should skip X"
        assert 'Y' in result.skipped_strings, "should skip Y"
        assert 'Z' in result.skipped_strings, "should skip Z"
        # Tree: [a, SyntaxError(X), b, SyntaxError(Y), c, SyntaxError(Z), d]

    def test_vis08_completion_vs_correction(self):
        # Completion (EOF): "user hasn't finished typing" - allowed
        comp = test_parse('S <- "if" "(" "x" ")" ;', 'if(x')
        assert comp.ok is True, "completion should succeed"

        # Correction (mid-parse): "user typed wrong thing" - NOT allowed via grammar deletion
        corr_result = squirrel_parse_pt(
            grammar_spec='S <- "if" "(" "x" ")" ;',
            top_rule_name='S',
            input='if()',
        )
        # Would need to delete 'x' at position 3, but ')' remains - not EOF
        result = corr_result.root
        # Total failure: result is a SyntaxError spanning entire input
        assert isinstance(result, SyntaxError), "mid-parse correction should fail"

    def test_vis09_structural_integrity(self):
        # Tree must reflect what user sees, not what we wish they typed
        result = test_parse('S <- "(" "E" ")" ;', 'E)')
        # User sees: E, )
        # Should NOT reinterpret as: (, E, ) by "inserting" ( at start
        # Should fail - cannot delete '(' mid-parse
        assert result.ok is False, "should fail (cannot reorganize visible structure)"

    def test_vis10_visibility_with_nested_structures(self):
        # Nested Seq - errors at each level should preserve visibility
        result = test_parse('S <- ("a" "b") "c" ;', 'aXbc')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert 'X' in result.skipped_strings, "should skip X in inner Seq"
