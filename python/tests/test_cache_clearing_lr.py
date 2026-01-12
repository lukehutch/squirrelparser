# =============================================================================
# CACHE CLEARING BUG TESTS (Document 4 fix) and LR RE-EXPANSION TESTS
# =============================================================================

from .test_utils import test_parse


# ===========================================================================
# CACHE CLEARING BUG TESTS (Document 4 fix)
# ===========================================================================

class TestCacheClearingBug:
    """Non-LR incomplete result must be cleared when recovery state changes.
    Bug: foundLeftRec && condition prevents clearing non-LR incomplete results.
    """

    STALE_CLEAR_GRAMMAR = """
        S <- A+ "z" ;
        A <- "ab" / "a" ;
    """

    def test_f4_01_stale_non_lr_incomplete(self):
        """Phase 1: A+ matches 'a' at 0, fails at 'X'. Incomplete, len=1.
        Phase 2: A+ should skip 'X', match 'ab', get len=4.
        Bug: stale len=1 result returned without clearing."""
        r = test_parse(self.STALE_CLEAR_GRAMMAR, 'aXabz')
        assert r.ok is True, "should recover by skipping X"
        assert r.error_count == 1, "should have 1 error"
        assert any('X' in s for s in r.skipped_strings), "should skip X"

    def test_f4_02_stale_non_lr_incomplete_multi(self):
        """Multiple recovery points in non-LR repetition."""
        r = test_parse(self.STALE_CLEAR_GRAMMAR, 'aXaYabz')
        assert r.ok is True, "should recover from multiple errors"
        assert r.error_count == 2, "should have 2 errors"


class TestProbeContextPhase2:
    """probe() during Phase 2 must get fresh results."""

    PROBE_CONTEXT_GRAMMAR = """
        S <- A B ;
        A <- "a"+ ;
        B <- "a"* "z" ;
    """

    def test_f4_03_probe_context_phase2(self):
        """Bounded repetition uses probe() to check if B can match.
        probe() must not reuse stale Phase 2 results."""
        r = test_parse(self.PROBE_CONTEXT_GRAMMAR, 'aaaXz')
        assert r.ok is True, "should recover"
        assert r.error_count == 1, "should have 1 error"

    def test_f4_04_probe_at_boundary(self):
        """Edge case: probe at exact boundary between clauses."""
        r = test_parse(self.PROBE_CONTEXT_GRAMMAR, 'aXaz')
        assert r.ok is True, "should recover at boundary"


# ===========================================================================
# LR RE-EXPANSION TESTS (Complete LR + recovery context change)
# ===========================================================================

class TestLRReExpansion:
    """Direct LR must re-expand in Phase 2.
    NOTE: Using "+" "n" instead of "+n" to allow
    recovery to skip characters between '+' and 'n'.
    """

    DIRECT_LR_REEXPAND = """
        E <- E "+" "n" / "n" ;
    """

    def test_f1_lr_01_reexpand_simple(self):
        """Phase 1: E matches 'n' (len=1), complete.
        Phase 2: must re-expand to skip 'X' and get 'n+n+n' (len=6)."""
        r = test_parse(self.DIRECT_LR_REEXPAND, 'n+Xn+n', 'E')
        assert r.ok is True, "LR must re-expand in Phase 2"
        assert r.error_count == 1, "should have 1 error"
        assert any('X' in s for s in r.skipped_strings), "should skip X"

    def test_f1_lr_02_reexpand_multiple_errors(self):
        """Multiple errors in LR expansion."""
        r = test_parse(self.DIRECT_LR_REEXPAND, 'n+Xn+Yn+n', 'E')
        assert r.ok is True, "LR should handle multiple errors"
        assert r.error_count == 2, "should have 2 errors"

    def test_f1_lr_03_reexpand_at_start(self):
        """Error between base 'n' and '+' - recovery should skip X."""
        r = test_parse(self.DIRECT_LR_REEXPAND, 'nX+n+n', 'E')
        assert r.ok is True, "should recover by skipping X"
        assert r.error_count == 1, "should have 1 error"


class TestIndirectLRReExpansion:
    """Indirect LR re-expansion."""

    INDIRECT_LR_REEXPAND = """
        E <- F / "n" ;
        F <- E "+" "n" ;
    """

    def test_f1_lr_04_indirect_reexpand(self):
        r = test_parse(self.INDIRECT_LR_REEXPAND, 'n+Xn+n', 'E')
        assert r.ok is True, "indirect LR must re-expand"
        assert r.error_count == 1, "should have 1 error"


class TestMultiLevelLRReExpansion:
    """Multi-level LR (precedence grammar)."""

    PRECEDENCE_LR_REEXPAND = """
        E <- E "+" T / T ;
        T <- T "*" F / F ;
        F <- "(" E ")" / "n" ;
    """

    def test_f1_lr_05_multilevel_at_t(self):
        """Error at T level requires both E and T to re-expand."""
        r = test_parse(self.PRECEDENCE_LR_REEXPAND, 'n+n*Xn', 'E')
        assert r.ok is True, "multi-level LR must re-expand correctly"
        assert r.error_count >= 1, "should have at least 1 error"
        assert any('X' in s for s in r.skipped_strings), "should skip X"

    def test_f1_lr_06_multilevel_at_e(self):
        """Error at E level."""
        r = test_parse(self.PRECEDENCE_LR_REEXPAND, 'n+Xn*n', 'E')
        assert r.ok is True, "should recover at E level"
        assert r.error_count >= 1, "should have at least 1 error"

    def test_f1_lr_07_multilevel_nested_parens(self):
        """Error inside parentheses."""
        r = test_parse(self.PRECEDENCE_LR_REEXPAND, 'n+(nX*n)', 'E')
        assert r.ok is True, "should recover inside parens"


class TestLRProbeInteraction:
    """LR with probe() interaction."""

    LR_PROBE_GRAMMAR = """
        S <- E+ "z" ;
        E <- E "x" / "a" ;
    """

    def test_f2_lr_01_probe_during_expansion(self):
        """Repetition probes LR rule E for bounds checking."""
        r = test_parse(self.LR_PROBE_GRAMMAR, 'axaXz')
        assert r.ok is True, "probe of LR during Phase 2 should work"
        assert r.error_count == 1, "should have 1 error"

    def test_f2_lr_02_probe_multiple_lr(self):
        r = test_parse(self.LR_PROBE_GRAMMAR, 'axaxXz')
        assert r.ok is True, "should handle multiple LR matches before error"


# ===========================================================================
# recoveryVersion NECESSITY TESTS
# ===========================================================================

class TestRecoveryVersionNecessity:
    """Distinguish Phase 1 (v=0,e=false) from probe() in Phase 2 (v=1,e=false).
    NOTE: Grammar designed so A* and B don't compete for the same characters.
    A matches 'a', B matches 'bz'. This way skipping X and matching 'abz' works.
    """

    RECOVERY_VERSION_GRAMMAR = """
        S <- A* B ;
        A <- "a" ;
        B <- "b" "z" ;
    """

    def test_f3_rv_01_phase1_vs_probe(self):
        """Phase 1: A* matches empty at 0 (mismatch on 'X'). B fails.
        Phase 2: skip X, A* matches 'a', B matches 'bz'."""
        r = test_parse(self.RECOVERY_VERSION_GRAMMAR, 'Xabz')
        assert r.ok is True, "should skip X and match abz"
        assert r.error_count == 1, "should have 1 error"
        assert any('X' in s for s in r.skipped_strings), "should skip X"

    def test_f3_rv_02_cached_mismatch_reuse(self):
        """Mismatch cached in Phase 1 should not poison probe() in Phase 2."""
        mismatch_grammar = """
            S <- A* B "!" ;
            A <- "a" ;
            B <- "bbb" ;
        """
        r = test_parse(mismatch_grammar, 'aaXbbb!')
        assert r.ok is True, "mismatch from Phase 1 should not block Phase 2 probe"

    def test_f3_rv_03_incomplete_different_versions(self):
        """Incomplete result at (v=0,e=false) vs query at (v=1,e=false)."""
        incomplete_grammar = """
            S <- A? B ;
            A <- "aaa" ;
            B <- "a" "z" ;
        """
        # Phase 1: A? returns incomplete empty (can't match 'X')
        # Phase 2 probe: should recompute, not reuse Phase 1's incomplete
        r = test_parse(incomplete_grammar, 'Xaz')
        assert r.ok is True, "should recover despite incomplete from Phase 1"


# ===========================================================================
# DEEP INTERACTION TESTS
# ===========================================================================

class TestDeepInteraction:
    """LR + bounded repetition + recovery."""

    DEEP_INTERACTION_GRAMMAR = """
        S <- E ";" ;
        E <- E "+" T / T ;
        T <- F+ ;
        F <- "n" / "(" E ")" ;
    """

    def test_deep_01_lr_bounded_recovery(self):
        """LR at E level, bounded rep at T level, recovery needed."""
        r = test_parse(self.DEEP_INTERACTION_GRAMMAR, 'n+nnXn;')
        assert r.ok is True, "should recover in bounded rep under LR"

    def test_deep_02_nested_lr_recovery(self):
        """Recovery inside parenthesized expression under LR."""
        r = test_parse(self.DEEP_INTERACTION_GRAMMAR, 'n+(nXn);')
        assert r.ok is True, "should recover inside nested structure"

    def test_deep_03_multiple_levels(self):
        """Errors at multiple structural levels."""
        r = test_parse(self.DEEP_INTERACTION_GRAMMAR, 'nXn+nYn;')
        assert r.ok is True, "should handle errors at multiple levels"
        assert r.error_count >= 2, "should have at least 2 errors"
