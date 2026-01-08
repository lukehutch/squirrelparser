"""Visibility Constraint Tests - FIX #8 Verification"""
from squirrelparser import Str, Seq, First, Parser
from tests.test_utils import parse, count_deletions


class TestVisibilityConstraintTests:
    """Visibility Constraint Tests

    These tests verify that parse trees match visible input structure and that
    grammar deletion (inserting missing elements) only occurs at EOF.
    """

    def test_vis_01_terminal_atomicity(self) -> None:
        """VIS-01-terminal-atomicity"""
        # Multi-char terminals are atomic - can't skip through them
        from squirrelparser import SyntaxError as SyntaxErrorNode
        parser = Parser(
            rules={
                'S': Seq(Str('abc'), Str('def'))
            },
            input_str='abXdef',
        )
        result, used_recovery = parser.parse('S')
        # Should fail - can't match 'abc' with 'abX', and can't skip 'X' mid-terminal
        assert isinstance(result, SyntaxErrorNode), \
            'should fail (cannot skip within multi-char terminal)'

    def test_vis_02_grammar_deletion_at_eof(self) -> None:
        """VIS-02-grammar-deletion-at-eof"""
        # Grammar deletion (completion) allowed at EOF
        ok, err, _ = parse({
            'S': Seq(Str('a'), Str('b'), Str('c'))
        }, 'ab')
        assert ok, 'should succeed (delete c at EOF)'

        parser = Parser(
            rules={
                'S': Seq(Str('a'), Str('b'), Str('c'))
            },
            input_str='ab',
        )
        result, used_recovery = parser.parse('S')
        assert count_deletions(result) >= 1, 'should have deletion at EOF'

    def test_vis_03_grammar_deletion_mid_parse_forbidden(self) -> None:
        """VIS-03-grammar-deletion-mid-parse-forbidden"""
        # Grammar deletion NOT allowed mid-parse (FIX #8)
        from squirrelparser import SyntaxError as SyntaxErrorNode
        parser = Parser(
            rules={
                'S': Seq(Str('a'), Str('b'), Str('c'))
            },
            input_str='ac',
        )
        result, used_recovery = parser.parse('S')
        # Should fail - cannot delete 'b' at position 1 (not EOF)
        assert isinstance(result, SyntaxErrorNode), \
            'should fail (mid-parse grammar deletion violates Visibility Constraint)'

    def test_vis_04_tree_structure_matches_visible_input(self) -> None:
        """VIS-04-tree-structure-matches-visible-input"""
        # Parse tree structure should match visible input structure
        ok, err, skip = parse({
            'S': Seq(Str('a'), Str('b'), Str('c'))
        }, 'aXbc')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error'
        assert 'X' in ''.join(skip), 'should skip X'
        # Visible input: a, X, b, c (4 elements)
        # Tree: a, SyntaxError(X), b, c (4 nodes)

    def test_vis_05_hidden_deletion_creates_mismatch(self) -> None:
        """VIS-05-hidden-deletion-creates-mismatch"""
        # First tries alternatives; Seq needs 'b' but input is just 'a'
        parser = Parser(
            rules={
                'S': First(
                    Seq(Str('a'), Str('b')),
                    Str('c')
                )
            },
            input_str='a',
        )
        result, used_recovery = parser.parse('S')
        # First alternative: Try Seq - 'a' matches, 'b' missing at EOF
        #   - Could delete 'b' at EOF, but that gives len=1
        # Second alternative: Try 'c' - fails (input is 'a')
        # Should pick first alternative with completion
        assert result is not None and not result.is_mismatch, \
            'should succeed (first alternative with EOF deletion)'
        assert result.len == 1, 'should consume 1 char (a)'

    def test_vis_06_multiple_consecutive_skips(self) -> None:
        """VIS-06-multiple-consecutive-skips"""
        # Multiple consecutive errors should be merged into one region
        ok, err, skip = parse({
            'S': Seq(Str('a'), Str('b'), Str('c'))
        }, 'aXXXXbc')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error (entire XXXX region)'
        assert 'XXXX' in ''.join(skip), 'should skip XXXX as one region'

    def test_vis_07_alternating_content_and_errors(self) -> None:
        """VIS-07-alternating-content-and-errors"""
        # Pattern: valid, error, valid, error, valid, error, valid
        ok, err, skip = parse({
            'S': Seq(Str('a'), Str('b'), Str('c'), Str('d'))
        }, 'aXbYcZd')
        assert ok, 'should succeed'
        assert err == 3, 'should have 3 errors'
        assert 'X' in ''.join(skip), 'should skip X'
        assert 'Y' in ''.join(skip), 'should skip Y'
        assert 'Z' in ''.join(skip), 'should skip Z'
        # Tree: [a, SyntaxError(X), b, SyntaxError(Y), c, SyntaxError(Z), d]

    def test_vis_08_completion_vs_correction(self) -> None:
        """VIS-08-completion-vs-correction"""
        # Completion (EOF): "user hasn't finished typing" - allowed
        comp_ok, _, _ = parse({
            'S': Seq(Str('if'), Str('('), Str('x'), Str(')'))
        }, 'if(x')
        assert comp_ok, 'completion should succeed'

        # Correction (mid-parse): "user typed wrong thing" - NOT allowed via grammar deletion
        from squirrelparser import SyntaxError as SyntaxErrorNode
        corr = Parser(
            rules={
                'S': Seq(Str('if'), Str('('), Str('x'), Str(')'))
            },
            input_str='if()',
        )
        # Would need to delete 'x' at position 3, but ')' remains - not EOF
        result, used_recovery = corr.parse('S')
        assert isinstance(result, SyntaxErrorNode), \
            'mid-parse correction should fail'

    def test_vis_09_structural_integrity(self) -> None:
        """VIS-09-structural-integrity"""
        # Tree must reflect what user sees, not what we wish they typed
        from squirrelparser import SyntaxError as SyntaxErrorNode
        parser = Parser(
            rules={
                'S': Seq(Str('('), Str('E'), Str(')'))
            },
            input_str='E)',
        )
        result, used_recovery = parser.parse('S')
        # User sees: E, )
        # Should NOT reinterpret as: (, E, ) by "inserting" ( at start
        # Should fail - cannot delete '(' mid-parse
        assert isinstance(result, SyntaxErrorNode), 'should fail (cannot reorganize visible structure)'

    def test_vis_10_visibility_with_nested_structures(self) -> None:
        """VIS-10-visibility-with-nested-structures"""
        # Nested Seq - errors at each level should preserve visibility
        ok, err, skip = parse({
            'S': Seq(
                Seq(Str('a'), Str('b')),
                Str('c')
            )
        }, 'aXbc')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error'
        assert 'X' in ''.join(skip), 'should skip X in inner Seq'
