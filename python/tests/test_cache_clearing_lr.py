"""
CACHE CLEARING BUG TESTS (Document 4 fix) and LR RE-EXPANSION TESTS
"""
from squirrelparser import Str, Seq, First, OneOrMore, ZeroOrMore, Optional, Ref
from tests.test_utils import parse


class TestCacheClearingBugTests:
    """Cache Clearing Bug Tests"""

    # --- Non-LR incomplete result must be cleared when recovery state changes ---
    # Bug: foundLeftRec && condition prevents clearing non-LR incomplete results

    stale_clear_grammar = {
        'S': Seq(OneOrMore(Ref('A')), Str('z')),
        'A': First(Str('ab'), Str('a')),
    }

    def test_f4_01_stale_nonlr_incomplete(self) -> None:
        """F4-01-stale-nonLR-incomplete"""
        # Phase 1: A+ matches 'a' at 0, fails at 'X'. Incomplete, len=1.
        # Phase 2: A+ should skip 'X', match 'ab', get len=4
        # Bug: stale len=1 result returned without clearing
        ok, err, skip = parse(self.stale_clear_grammar, 'aXabz')
        assert ok, 'should recover by skipping X'
        assert err == 1, 'should have 1 error'
        assert any('X' in s for s in skip), 'should skip X'

    def test_f4_02_stale_nonlr_incomplete_multi(self) -> None:
        """F4-02-stale-nonLR-incomplete-multi"""
        # Multiple recovery points in non-LR repetition
        ok, err, skip = parse(self.stale_clear_grammar, 'aXaYabz')
        assert ok, 'should recover from multiple errors'
        assert err == 2, 'should have 2 errors'

    # --- probe() during Phase 2 must get fresh results ---
    probe_context_grammar = {
        'S': Seq(Ref('A'), Ref('B')),
        'A': OneOrMore(Str('a')),
        'B': Seq(ZeroOrMore(Str('a')), Str('z')),
    }

    def test_f4_03_probe_context_phase2(self) -> None:
        """F4-03-probe-context-phase2"""
        # Bounded repetition uses probe() to check if B can match
        # probe() must not reuse stale Phase 2 results
        ok, err, skip = parse(self.probe_context_grammar, 'aaaXz')
        assert ok, 'should recover'
        assert err == 1, 'should have 1 error'

    def test_f4_04_probe_at_boundary(self) -> None:
        """F4-04-probe-at-boundary"""
        # Edge case: probe at exact boundary between clauses
        ok, err, skip = parse(self.probe_context_grammar, 'aXaz')
        assert ok, 'should recover at boundary'


class TestLRReexpansionTests:
    """LR Re-expansion Tests"""

    # --- Direct LR must re-expand in Phase 2 ---
    # NOTE: Using Seq([Str('+'), Str('n')]) instead of Str('+n') to allow
    # recovery to skip characters between '+' and 'n'.
    direct_lr_reexpand = {
        'E': First(
            Seq(Ref('E'), Str('+'), Str('n')),
            Str('n')
        ),
    }

    def test_f1_lr_01_reexpand_simple(self) -> None:
        """F1-LR-01-reexpand-simple"""
        # Phase 1: E matches 'n' (len=1), complete
        # Phase 2: must re-expand to skip 'X' and get 'n+n+n' (len=6)
        ok, err, skip = parse(self.direct_lr_reexpand, 'n+Xn+n', 'E')
        assert ok, 'LR must re-expand in Phase 2'
        assert err == 1, 'should have 1 error'
        assert any('X' in s for s in skip), 'should skip X'

    def test_f1_lr_02_reexpand_multiple_errors(self) -> None:
        """F1-LR-02-reexpand-multiple-errors"""
        # Multiple errors in LR expansion
        ok, err, skip = parse(self.direct_lr_reexpand, 'n+Xn+Yn+n', 'E')
        assert ok, 'LR should handle multiple errors'
        assert err == 2, 'should have 2 errors'

    def test_f1_lr_03_reexpand_at_start(self) -> None:
        """F1-LR-03-reexpand-at-start"""
        # Error between base 'n' and '+' - recovery should skip X
        ok, err, skip = parse(self.direct_lr_reexpand, 'nX+n+n', 'E')
        assert ok, 'should recover by skipping X'
        assert err == 1, 'should have 1 error'

    # --- Indirect LR re-expansion ---
    indirect_lr_reexpand = {
        'E': First(Ref('F'), Str('n')),
        'F': Seq(Ref('E'), Str('+'), Str('n')),
    }

    def test_f1_lr_04_indirect_reexpand(self) -> None:
        """F1-LR-04-indirect-reexpand"""
        ok, err, skip = parse(self.indirect_lr_reexpand, 'n+Xn+n', 'E')
        assert ok, 'indirect LR must re-expand'
        assert err == 1, 'should have 1 error'

    # --- Multi-level LR (precedence grammar) ---
    precedence_lr_reexpand = {
        'E': First(
            Seq(Ref('E'), Str('+'), Ref('T')),
            Ref('T')
        ),
        'T': First(
            Seq(Ref('T'), Str('*'), Ref('F')),
            Ref('F')
        ),
        'F': First(
            Seq(Str('('), Ref('E'), Str(')')),
            Str('n')
        ),
    }

    def test_f1_lr_05_multilevel_at_t(self) -> None:
        """F1-LR-05-multilevel-at-T"""
        # Error at T level requires both E and T to re-expand
        ok, err, skip = parse(self.precedence_lr_reexpand, 'n+n*Xn', 'E')
        assert ok, 'multi-level LR must re-expand correctly'
        assert err >= 1, 'should have at least 1 error'
        assert any('X' in s for s in skip), 'should skip X'

    def test_f1_lr_06_multilevel_at_e(self) -> None:
        """F1-LR-06-multilevel-at-E"""
        # Error at E level
        ok, err, skip = parse(self.precedence_lr_reexpand, 'n+Xn*n', 'E')
        assert ok, 'should recover at E level'
        assert err >= 1, 'should have at least 1 error'

    def test_f1_lr_07_multilevel_nested_parens(self) -> None:
        """F1-LR-07-multilevel-nested-parens"""
        # Error inside parentheses
        ok, err, skip = parse(self.precedence_lr_reexpand, 'n+(nX*n)', 'E')
        assert ok, 'should recover inside parens'

    # --- LR with probe() interaction ---
    lr_probe_grammar = {
        'S': Seq(OneOrMore(Ref('E')), Str('z')),
        'E': First(
            Seq(Ref('E'), Str('x')),
            Str('a')
        ),
    }

    def test_f2_lr_01_probe_during_expansion(self) -> None:
        """F2-LR-01-probe-during-expansion"""
        # Repetition probes LR rule E for bounds checking
        ok, err, skip = parse(self.lr_probe_grammar, 'axaXz')
        assert ok, 'probe of LR during Phase 2 should work'
        assert err == 1, 'should have 1 error'

    def test_f2_lr_02_probe_multiple_lr(self) -> None:
        """F2-LR-02-probe-multiple-LR"""
        ok, err, skip = parse(self.lr_probe_grammar, 'axaxXz')
        assert ok, 'should handle multiple LR matches before error'


class TestRecoveryVersionNecessityTests:
    """Recovery Version Necessity Tests"""

    # --- Distinguish Phase 1 (v=0,e=false) from probe() in Phase 2 (v=1,e=false) ---
    # NOTE: Grammar designed so A* and B don't compete for the same characters.
    # A matches 'a', B matches 'bz'. This way skipping X and matching 'abz' works.
    recovery_version_grammar = {
        'S': Seq(ZeroOrMore(Ref('A')), Ref('B')),
        'A': Str('a'),
        'B': Seq(Str('b'), Str('z')),
    }

    def test_f3_rv_01_phase1_vs_probe(self) -> None:
        """F3-RV-01-phase1-vs-probe"""
        # Phase 1: A* matches empty at 0 (mismatch on 'X'). B fails.
        # Phase 2: skip X, A* matches 'a', B matches 'bz'.
        ok, err, skip = parse(self.recovery_version_grammar, 'Xabz')
        assert ok, 'should skip X and match abz'
        assert err == 1, 'should have 1 error'
        assert any('X' in s for s in skip), 'should skip X'

    def test_f3_rv_02_cached_mismatch_reuse(self) -> None:
        """F3-RV-02-cached-mismatch-reuse"""
        # Mismatch cached in Phase 1 should not poison probe() in Phase 2
        mismatch_grammar = {
            'S': Seq(ZeroOrMore(Ref('A')), Ref('B'), Str('!')),
            'A': Str('a'),
            'B': Str('bbb'),
        }
        ok, err, skip = parse(mismatch_grammar, 'aaXbbb!')
        assert ok, 'mismatch from Phase 1 should not block Phase 2 probe'

    def test_f3_rv_03_incomplete_different_versions(self) -> None:
        """F3-RV-03-incomplete-different-versions"""
        # Incomplete result at (v=0,e=false) vs query at (v=1,e=false)
        incomplete_grammar = {
            'S': Seq(Optional(Ref('A')), Ref('B')),
            'A': Str('aaa'),
            'B': Seq(Str('a'), Str('z')),
        }
        # Phase 1: A? returns incomplete empty (can't match 'X')
        # Phase 2 probe: should recompute, not reuse Phase 1's incomplete
        ok, err, skip = parse(incomplete_grammar, 'Xaz')
        assert ok, 'should recover despite incomplete from Phase 1'


class TestDeepInteractionTests:
    """Deep Interaction Tests"""

    # --- LR + bounded repetition + recovery ---
    deep_interaction_grammar = {
        'S': Seq(Ref('E'), Str(';')),
        'E': First(
            Seq(Ref('E'), Str('+'), Ref('T')),
            Ref('T')
        ),
        'T': OneOrMore(Ref('F')),
        'F': First(
            Str('n'),
            Seq(Str('('), Ref('E'), Str(')'))
        ),
    }

    def test_deep_01_lr_bounded_recovery(self) -> None:
        """DEEP-01-LR-bounded-recovery"""
        # LR at E level, bounded rep at T level, recovery needed
        ok, err, skip = parse(self.deep_interaction_grammar, 'n+nnXn;')
        assert ok, 'should recover in bounded rep under LR'

    def test_deep_02_nested_lr_recovery(self) -> None:
        """DEEP-02-nested-LR-recovery"""
        # Recovery inside parenthesized expression under LR
        ok, err, skip = parse(self.deep_interaction_grammar, 'n+(nXn);')
        assert ok, 'should recover inside nested structure'

    def test_deep_03_multiple_levels(self) -> None:
        """DEEP-03-multiple-levels"""
        # Errors at multiple structural levels
        ok, err, skip = parse(self.deep_interaction_grammar, 'nXn+nYn;')
        assert ok, 'should handle errors at multiple levels'
        assert err >= 2, 'should have at least 2 errors'
