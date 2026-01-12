# ===========================================================================
# LEFT RECURSION + RECOVERY INTERACTION TESTS
# ===========================================================================
# These tests verify that error recovery works correctly during and after
# left-recursive expansion.

from .test_utils import test_parse


class TestLRRecoveryInteraction:
    """LR + Recovery Interaction Tests."""

    def test_lr_int_01_recovery_during_base_case(self):
        """Error during LR base case - trailing captured with new invariant."""
        grammar = """
            E <- E "+" "n" / "n" ;
        """
        r = test_parse(grammar, 'nX', 'E')
        # Base case matches 'n', 'X' captured as trailing error
        assert r.ok is True, "should succeed with trailing captured"
        assert r.error_count == 1, "should have 1 error (trailing X)"
        assert any('X' in s for s in r.skipped_strings), "should skip X"

    def test_lr_int_02_recovery_during_growth(self):
        """Error during LR growth phase."""
        grammar = """
            E <- E "+" "n" / "n" ;
        """
        r = test_parse(grammar, 'n+Xn', 'E')
        assert r.ok is True, "should succeed"
        assert r.error_count == 1, "should have 1 error"
        assert any('X' in s for s in r.skipped_strings), "should skip X"
        # Base: n, Growth: n + [skip X] n

    def test_lr_int_03_multiple_errors_during_expansion(self):
        """Multiple errors across multiple expansion iterations."""
        grammar = """
            E <- E "+" "n" / "n" ;
        """
        r = test_parse(grammar, 'n+Xn+Yn+Zn', 'E')
        assert r.ok is True, "should succeed"
        assert r.error_count == 3, "should have 3 errors"
        assert any('X' in s for s in r.skipped_strings), "should skip X"
        assert any('Y' in s for s in r.skipped_strings), "should skip Y"
        assert any('Z' in s for s in r.skipped_strings), "should skip Z"

    def test_lr_int_04_nested_lr_with_recovery(self):
        """E -> E + T | T, T -> T * n | n."""
        grammar = """
            E <- E "+" T / T ;
            T <- T "*" "n" / "n" ;
        """
        r = test_parse(grammar, 'n*Xn+n*Yn', 'E')
        assert r.ok is True, "should succeed"
        assert r.error_count == 2, "should have 2 errors (X in first term, Y in second term)"
        assert any('X' in s for s in r.skipped_strings), "should skip X"
        assert any('Y' in s for s in r.skipped_strings), "should skip Y"

    def test_lr_int_05_lr_expansion_stops_on_trailing_error(self):
        """LR expands as far as possible, trailing captured with new invariant."""
        grammar = """
            E <- E "+" "n" / "n" ;
        """
        r = test_parse(grammar, 'n+n+nX', 'E')
        # Expansion: n, n+n, n+n+n (len=5), then 'X' captured as trailing
        assert r.ok is True, "should succeed with trailing captured"
        assert r.error_count == 1, "should have 1 error (trailing X)"
        assert any('X' in s for s in r.skipped_strings), "should skip X"

    def test_lr_int_06_cache_invalidation_during_recovery(self):
        """Phase 1: E@0 marked incomplete
        Phase 2: E@0 must re-expand with recovery."""
        grammar = """
            E <- E "+" "n" / "n" ;
        """
        r = test_parse(grammar, 'n+Xn', 'E')
        assert r.ok is True, "should succeed"
        assert r.error_count == 1, "should have 1 error"
        assert any('X' in s for s in r.skipped_strings), "should skip X"
        # FIX #6: Cache must be invalidated for LR re-expansion

    def test_lr_int_07_lr_with_repetition_and_recovery(self):
        """E -> E + n+ | n (nested repetition in LR)."""
        grammar = """
            E <- E "+" "n"+ / "n" ;
        """
        r = test_parse(grammar, 'n+nXnn', 'E')
        assert r.ok is True, "should succeed"
        assert r.error_count == 1, "should have 1 error"
        assert any('X' in s for s in r.skipped_strings), "should skip X in n+"

    def test_lr_int_08_is_from_lr_context_flag(self):
        """Successful LR results are marked with isFromLRContext
        But this shouldn't prevent parent recovery (FIX #1)."""
        grammar = """
            S <- E "end" ;
            E <- E "+" "n" / "n" ;
        """
        r = test_parse(grammar, 'n+nend')
        assert r.ok is True, "should succeed"
        # E is left-recursive and successful, marked with isFromLRContext
        # But 'end' should still match (FIX #1: only MISMATCH blocks recovery)

    def test_lr_int_09_failed_lr_doesnt_block_recovery(self):
        """Failed LR (MISMATCH) should NOT be marked isFromLRContext
        This allows parent to attempt recovery."""
        grammar = """
            S <- E "x" ;
            E <- E "+" "n" / "n" ;
        """
        # Input where E succeeds with recovery, then x matches
        r = test_parse(grammar, 'nXnx')
        assert r.ok is True, "should succeed"
        assert r.error_count == 1, "should have 1 error (skip X)"
        # E matches 'nXn' with recovery, then 'x' matches

    def test_lr_int_10_deep_lr_nesting(self):
        """Multiple levels of LR with recovery at each level."""
        grammar = """
            S <- S "a" T / T ;
            T <- T "b" "x" / "x" ;
        """
        r = test_parse(grammar, 'xbXxaXxbx', 'S')
        assert r.ok is True, "should succeed"
        assert r.error_count == 2, "should have 2 errors (X at both levels)"
        # Complex nesting: S and T both left-recursive, errors at both levels
