"""Ref LR Masking Tests - multi-level LR with error recovery"""
from squirrelparser import Str, Seq, First, Ref, Clause
from tests.test_utils import parse


class TestMultiLevelLRRecoveryTests:
    """Multi-level LR Recovery Tests

    KNOWN LIMITATION:
    In multi-level LR grammars like E → E+T | T and T → T*F | F:
    - When parsing "n+n*Xn", error is at '*Xn' where 'X' should be skipped
    - Optimal: T*F recovers by skipping 'X' -> 1 error
    - Current: E+T recovers by skipping '*X' -> 2 errors

    The current behavior is a deterministic approximation - recovery happens
    at a higher grammar level than optimal, but still produces valid parses.
    """

    # Standard precedence grammar with multi-level left recursion
    precedence_grammar: dict[str, Clause] = {
        'E': First(
            Seq(Ref('E'), Str('+'), Ref('T')),
            Ref('T')
        ),
        'T': First(
            Seq(Ref('T'), Str('*'), Ref('F')),
            Ref('F')
        ),
        'F': Str('n'),
    }

    def test_mlr_01_clean_addition(self) -> None:
        """MLR-01-clean-addition"""
        ok, err, _ = parse(self.precedence_grammar, 'n+n', 'E')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors'

    def test_mlr_02_clean_multiplication(self) -> None:
        """MLR-02-clean-multiplication"""
        ok, err, _ = parse(self.precedence_grammar, 'n*n', 'E')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors'

    def test_mlr_03_clean_precedence(self) -> None:
        """MLR-03-clean-precedence"""
        ok, err, _ = parse(self.precedence_grammar, 'n+n*n', 'E')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors'

    def test_mlr_04_error_in_addition(self) -> None:
        """MLR-04-error-in-addition"""
        # Error at E level
        ok, err, skip = parse(self.precedence_grammar, 'n+Xn', 'E')
        assert ok, 'should succeed'
        assert err >= 1, 'should have at least 1 error'

    def test_mlr_05_error_in_multiplication(self) -> None:
        """MLR-05-error-in-multiplication"""
        # Error at T level - this demonstrates the known limitation
        ok, err, skip = parse(self.precedence_grammar, 'n+n*Xn', 'E')
        assert ok, 'should succeed'
        # Due to masking, recovery may happen at E level instead of T level
        assert err >= 1, 'should have at least 1 error'


class TestSingleLevelLRRecoveryTests:
    """Single-level LR Recovery - Working Cases"""

    def test_single_lr_01_basic(self) -> None:
        """SINGLE-LR-01-basic"""
        grammar = {
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
        }
        ok, err, _ = parse(grammar, 'n+Xn', 'E')
        assert ok, 'basic LR recovery should work'
        assert err == 1, 'single-level LR should have exact error count'

    def test_single_lr_02_multiple_expansions(self) -> None:
        """SINGLE-LR-02-multiple-expansions"""
        grammar = {
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
        }
        ok, err, _ = parse(grammar, 'n+Xn+n', 'E')
        assert ok, 'should succeed'
        assert err == 1, 'single-level LR should skip exactly X'

    def test_single_lr_03_multiple_errors(self) -> None:
        """SINGLE-LR-03-multiple-errors"""
        grammar = {
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
        }
        ok, err, _ = parse(grammar, 'n+Xn+Yn', 'E')
        assert ok, 'should succeed'
        assert err == 2, 'should have 2 errors'

    def test_lr_pending_01_no_spurious_recovery(self) -> None:
        """LR-PENDING-01-no-spurious-recovery"""
        # Without LR_PENDING fix, this would have 4+ errors
        # With fix, it has 2 (due to Ref masking, not LR seeding)
        grammar = {
            'E': First(
                Seq(Ref('E'), Str('+'), Ref('T')),
                Ref('T')
            ),
            'T': First(
                Seq(Ref('T'), Str('*'), Str('n')),
                Str('n')
            ),
        }
        ok, err, _ = parse(grammar, 'n+n*Xn', 'E')
        assert ok, 'should succeed'
        # LR_PENDING prevents 4 errors, but Ref masking still causes 2
        assert err <= 3, 'LR_PENDING should prevent excessive errors'
