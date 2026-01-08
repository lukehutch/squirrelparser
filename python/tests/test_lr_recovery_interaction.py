"""LR + Recovery Interaction Tests"""
from squirrelparser import Str, Seq, First, OneOrMore, Ref
from tests.test_utils import parse


class TestLRRecoveryInteractionTests:
    """LR + Recovery Interaction Tests"""

    def test_lr_int_01_recovery_during_base_case(self) -> None:
        """LR-INT-01-recovery-during-base-case"""
        # Error during LR base case - with spanning invariant, parser recovers
        ok, err, skip = parse({
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            )
        }, 'nX', 'E')
        # Base case matches 'n', 'X' is skipped as error with recovery
        assert ok, 'should recover from trailing X'
        assert err == 1, 'should have 1 error (X)'
        assert 'X' in skip, 'should skip X'

    def test_lr_int_02_recovery_during_growth(self) -> None:
        """LR-INT-02-recovery-during-growth"""
        # Error during LR growth phase
        ok, err, skip = parse({
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            )
        }, 'n+Xn', 'E')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error'
        assert 'X' in ''.join(skip), 'should skip X'
        # Base: n, Growth: n + [skip X] n

    def test_lr_int_03_multiple_errors_during_expansion(self) -> None:
        """LR-INT-03-multiple-errors-during-expansion"""
        # Multiple errors across multiple expansion iterations
        ok, err, skip = parse({
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            )
        }, 'n+Xn+Yn+Zn', 'E')
        assert ok, 'should succeed'
        assert err == 3, 'should have 3 errors'
        skip_str = ''.join(skip)
        assert 'X' in skip_str, 'should skip X'
        assert 'Y' in skip_str, 'should skip Y'
        assert 'Z' in skip_str, 'should skip Z'

    def test_lr_int_04_nested_lr_with_recovery(self) -> None:
        """LR-INT-04-nested-lr-with-recovery"""
        # E -> E + T | T, T -> T * n | n
        ok, err, skip = parse({
            'E': First(
                Seq(Ref('E'), Str('+'), Ref('T')),
                Ref('T')
            ),
            'T': First(
                Seq(Ref('T'), Str('*'), Str('n')),
                Str('n')
            )
        }, 'n*Xn+n*Yn', 'E')
        assert ok, 'should succeed'
        assert err == 2, 'should have 2 errors (X in first term, Y in second term)'
        skip_str = ''.join(skip)
        assert 'X' in skip_str, 'should skip X'
        assert 'Y' in skip_str, 'should skip Y'

    def test_lr_int_05_lr_expansion_stops_on_trailing_error(self) -> None:
        """LR-INT-05-lr-expansion-stops-on-trailing-error"""
        # LR expands as far as possible, with spanning invariant, recovers from trailing garbage
        ok, err, skip = parse({
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            )
        }, 'n+n+nX', 'E')
        # Expansion: n, n+n, n+n+n (len=5), then 'X' at position 5 is skipped
        assert ok, 'should recover from trailing garbage'
        assert err == 1, 'should have 1 error (X)'
        assert 'X' in skip, 'should skip X'

    def test_lr_int_06_cache_invalidation_during_recovery(self) -> None:
        """LR-INT-06-cache-invalidation-during-recovery"""
        # Phase 1: E@0 marked incomplete
        # Phase 2: E@0 must re-expand with recovery
        ok, err, skip = parse({
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            )
        }, 'n+Xn', 'E')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error'
        assert 'X' in ''.join(skip), 'should skip X'
        # FIX #6: Cache must be invalidated for LR re-expansion

    def test_lr_int_07_lr_with_repetition_and_recovery(self) -> None:
        """LR-INT-07-lr-with-repetition-and-recovery"""
        # E -> E + n+ | n (nested repetition in LR)
        ok, err, skip = parse({
            'E': First(
                Seq(Ref('E'), Str('+'), OneOrMore(Str('n'))),
                Str('n')
            )
        }, 'n+nXnn', 'E')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error'
        assert 'X' in ''.join(skip), 'should skip X in n+'

    def test_lr_int_08_is_from_lr_context_flag(self) -> None:
        """LR-INT-08-isFromLRContext-flag"""
        # Successful LR results are marked with isFromLRContext
        # But this shouldn't prevent parent recovery (FIX #1)
        ok, _, _ = parse({
            'S': Seq(Ref('E'), Str('end')),
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            )
        }, 'n+nend')
        assert ok, 'should succeed'
        # E is left-recursive and successful, marked with isFromLRContext
        # But 'end' should still match (FIX #1: only MISMATCH blocks recovery)

    def test_lr_int_09_failed_lr_doesnt_block_recovery(self) -> None:
        """LR-INT-09-failed-lr-doesnt-block-recovery"""
        # Failed LR (MISMATCH) should NOT be marked isFromLRContext
        # This allows parent to attempt recovery
        grammar = {
            'S': Seq(Ref('E'), Str('x')),
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            )
        }
        # Input where E succeeds with recovery, then x matches
        ok, err, skip = parse(grammar, 'nXnx')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error (skip X)'
        # E matches 'nXn' with recovery, then 'x' matches

    def test_lr_int_10_deep_lr_nesting(self) -> None:
        """LR-INT-10-deep-lr-nesting"""
        # Multiple levels of LR with recovery at each level
        ok, err, _ = parse({
            'S': First(
                Seq(Ref('S'), Str('a'), Ref('T')),
                Ref('T')
            ),
            'T': First(
                Seq(Ref('T'), Str('b'), Str('x')),
                Str('x')
            )
        }, 'xbXxaXxbx', 'S')
        assert ok, 'should succeed'
        assert err == 2, 'should have 2 errors (X at both levels)'
        # Complex nesting: S and T both left-recursive, errors at both levels
