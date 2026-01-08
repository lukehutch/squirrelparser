"""Comprehensive Fix Tests"""
from squirrelparser import Str, Seq, First, Ref
from tests.test_utils import parse


class TestComprehensiveFixTests:
    """Comprehensive Fix Tests"""

    def test_fix3_01_ref_transparency_lr_reexpansion(self) -> None:
        """FIX3-01-ref-transparency-lr-reexpansion"""
        # During recovery, Ref should allow LR to re-expand
        grammar = {
            'S': Seq(Ref('E'), Str(';')),
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
        }
        ok, err, _ = parse(grammar, 'n+Xn;')
        assert ok, 'Ref should allow LR re-expansion during recovery'
        assert err == 1, 'should skip X'

    def test_fix4_01_single_char_skip_junk(self) -> None:
        """FIX4-01-single-char-skip-junk"""
        # Single-char terminal can skip arbitrary junk
        grammar = {
            'S': Seq(Str('a'), Str('b'), Str('c'))
        }
        ok, err, skip = parse(grammar, 'aXXbc')
        assert ok, 'should skip junk XX'
        assert err == 1, 'one skip'
        assert 'XX' in ''.join(skip)

    def test_fix4_02_single_char_no_skip_containing_terminal(self) -> None:
        """FIX4-02-single-char-no-skip-containing-terminal"""
        # Single-char terminal should NOT skip if junk contains the terminal
        grammar = {
            'S': Seq(Str('a'), Str('b'), Str('c'))
        }
        ok, _, _ = parse(grammar, 'aXbYc')
        # This might succeed by skipping X, matching b, skipping Y (2 errors)
        # The key is it shouldn't skip "Xb" as one unit
        assert ok, 'should recover with multiple skips'

    def test_fix4_03_multi_char_atomic_terminal(self) -> None:
        """FIX4-03-multi-char-atomic-terminal"""
        # Multi-char terminal is atomic - but with spanning invariant, parser recovers
        # The recovery produces a SyntaxError node for the unmatched portion
        grammar = {
            'S': Ref('E'),
            'E': First(
                Seq(Ref('E'), Str('+n')),
                Str('n')
            ),
        }
        ok, err, skip = parse(grammar, 'n+Xn+n')
        # With spanning invariant, recovers but marks the problematic region as skipped
        assert ok, 'should recover with skip'
        assert err == 1, 'should have 1 error'
        # The problematic region is skipped as a single error
        assert len(skip) > 0, 'should skip the problem region'

    def test_fix4_04_multi_char_exact_skip_ok(self) -> None:
        """FIX4-04-multi-char-exact-skip-ok"""
        # Multi-char terminal can skip exactly its length if needed
        grammar = {
            'S': Seq(Str('ab'), Str('cd'))
        }
        ok, err, _ = parse(grammar, 'abXYcd')
        assert ok, 'can skip 2 chars for 2-char terminal'
        assert err == 1, 'one skip'

    def test_fix5_01_no_skip_containing_next_terminal(self) -> None:
        """FIX5-01-no-skip-containing-next-terminal"""
        # During recovery, don't skip content that includes next terminal
        grammar = {
            'S': Seq(Ref('E'), Str(';'), Ref('E')),
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
        }
        ok, err, _ = parse(grammar, 'n+Xn;n+n+n')
        assert ok, 'should recover'
        assert err == 1, 'only skip X in first E, not consume ;n'

    def test_fix5_02_skip_pure_junk_ok(self) -> None:
        """FIX5-02-skip-pure-junk-ok"""
        # Can skip junk that doesn't contain next terminal
        grammar = {
            'S': Seq(Str('+'), Str('n'))
        }
        ok, err, skip = parse(grammar, '+XXn')
        assert ok, 'should skip XX'
        assert err == 1, 'one skip'
        assert 'XX' in ''.join(skip)

    def test_combined_01_lr_with_skip_and_delete(self) -> None:
        """COMBINED-01-lr-with-skip-and-delete"""
        # LR expansion + recovery with both skip and delete
        grammar = {
            'S': Seq(Ref('E')),
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
        }
        ok, _, _ = parse(grammar, 'n+Xn+Yn')
        assert ok, 'should handle multiple errors in LR'

    def test_combined_02_first_prefers_longer_with_errors(self) -> None:
        """COMBINED-02-first-prefers-longer-with-errors"""
        # First should prefer longer match even if it has more errors
        grammar = {
            'S': First(
                Seq(Str('a'), Str('b'), Str('c')),  # 3 chars
                Str('a')  # 1 char
            ),
        }
        ok, err, _ = parse(grammar, 'aXbc')
        assert ok, 'should choose longer alternative'
        assert err == 1, 'skip X'
        # Result should be "abc" not just "a"

    def test_combined_03_nested_seq_recovery(self) -> None:
        """COMBINED-03-nested-seq-recovery"""
        # Nested sequences with recovery at different levels
        grammar = {
            'S': Seq(Ref('A'), Str(';'), Ref('B')),
            'A': Seq(Str('a'), Str('x')),
            'B': Seq(Str('b'), Str('y')),
        }
        ok, err, _ = parse(grammar, 'aXx;bYy')
        assert ok, 'nested recovery should work'
        assert err == 2, 'skip X and Y'
