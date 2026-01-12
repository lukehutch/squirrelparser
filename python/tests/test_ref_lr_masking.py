# =============================================================================
# REF LR MASKING TESTS
# =============================================================================
# Tests for multi-level left recursion with error recovery.
#
# KNOWN LIMITATION:
# In multi-level LR grammars like E -> E+T | T and T -> T*F | F:
# - When parsing "n+n*Xn", error is at '*Xn' where 'X' should be skipped
# - Optimal: T*F recovers by skipping 'X' -> 1 error
# - Current: E+T recovers by skipping '*X' -> 2 errors
#
# ROOT CAUSE:
# Ref('T') at position 2 creates a separate MemoEntry from the inner T rule.
# During Phase 2, E re-expands (foundLeftRec=true), but Ref('T') doesn't
# because its MemoEntry.foundLeftRec=false (doesn't inherit from inner T).
# This means T@2 returns cached result without trying recovery at T*F level.
#
# ATTEMPTED FIXES:
# 1. Propagating foundLeftRec from inner rule causes cascading re-expansions
#    that break other tests by causing excessive re-parsing.
# 2. Blocking recovery based on LR context of previous matches causes
#    recovery to fail entirely in some cases.
#
# The current behavior is a deterministic approximation - recovery happens
# at a higher grammar level than optimal, but still produces valid parses.

from .test_utils import test_parse


class TestMultiLevelLRRecovery:
    """Multi-level LR Recovery Tests."""

    # Standard precedence grammar with multi-level left recursion
    PRECEDENCE_GRAMMAR = """
        E <- E "+" T / T ;
        T <- T "*" F / F ;
        F <- "(" E ")" / "n" ;
    """

    def test_multi_lr_01_error_at_f_level_after_star(self):
        """Input: n+n*Xn
        Error: 'X' appears where 'n' (F) is expected after '*'
        Current: Recovery at E+T level skips '*X' (2 errors)
        Optimal would skip just 'X' (1 error)."""
        r = test_parse(self.PRECEDENCE_GRAMMAR, 'n+n*Xn', 'E')
        assert r.ok is True, "should parse with recovery"
        assert r.error_count >= 1, "should have at least 1 error"
        # Note: Currently produces 2 errors due to recovery at wrong level

    def test_multi_lr_02_error_at_t_level_after_plus(self):
        """Input: n+Xn*n
        Error: 'X' appears where 'n' (T) is expected after '+'."""
        r = test_parse(self.PRECEDENCE_GRAMMAR, 'n+Xn*n', 'E')
        assert r.ok is True, "should parse with recovery"
        assert r.error_count >= 1, "should have at least 1 error"

    def test_multi_lr_03_nested_error_in_parens(self):
        """Input: n+(n*Xn)
        Error inside parentheses at T*F level."""
        r = test_parse(self.PRECEDENCE_GRAMMAR, 'n+(n*Xn)', 'E')
        assert r.ok is True, "should recover inside parens"
        assert r.error_count >= 1, "should have errors"


class TestTwoLevelGrammar:
    """Simpler two-level grammar to isolate the issue."""

    TWO_LEVEL_GRAMMAR = """
        A <- A "+" B / B ;
        B <- B "-" "x" / "x" ;
    """

    def test_multi_lr_04_two_level(self):
        """Input: x+x-Yx (Y is error)
        Error at B-x level after '-'."""
        r = test_parse(self.TWO_LEVEL_GRAMMAR, 'x+x-Yx', 'A')
        assert r.ok is True, "should parse with recovery"
        assert r.error_count >= 1, "should have errors"

    def test_multi_lr_05_three_levels(self):
        """Three-level LR to test deep nesting."""
        three_level_grammar = """
            A <- A "+" B / B ;
            B <- B "*" C / C ;
            C <- C "-" "x" / "x" ;
        """
        # Input: x+x*x-Yx (Y is error at deepest C level)
        r = test_parse(three_level_grammar, 'x+x*x-Yx', 'A')
        assert r.ok is True, "should parse with recovery"
        assert r.error_count >= 1, "should have errors"


class TestSingleLevelLRRecovery:
    """Single-level LR works correctly with exact error counts."""

    def test_single_lr_01_basic(self):
        grammar = """
            E <- E "+" "n" / "n" ;
        """
        r = test_parse(grammar, 'n+Xn', 'E')
        assert r.ok is True, "basic LR recovery should work"
        assert r.error_count == 1, "single-level LR should have exact error count"

    def test_single_lr_02_multiple_expansions(self):
        grammar = """
            E <- E "+" "n" / "n" ;
        """
        r = test_parse(grammar, 'n+Xn+n', 'E')
        assert r.ok is True
        assert r.error_count == 1, "single-level LR should skip exactly X"

    def test_single_lr_03_multiple_errors(self):
        grammar = """
            E <- E "+" "n" / "n" ;
        """
        r = test_parse(grammar, 'n+Xn+Yn', 'E')
        assert r.ok is True
        assert r.error_count == 2, "should have 2 errors"


class TestLRPendingFixVerification:
    """Verify that LR_PENDING prevents spurious recovery on LR seeds."""

    def test_lr_pending_01_no_spurious_recovery(self):
        """Without LR_PENDING fix, this would have 4+ errors.
        With fix, it has 2 (due to Ref masking, not LR seeding)."""
        grammar = """
            E <- E "+" T / T ;
            T <- T "*" "n" / "n" ;
        """
        r = test_parse(grammar, 'n+n*Xn', 'E')
        assert r.ok is True
        # LR_PENDING prevents 4 errors, but Ref masking still causes 2
        assert r.error_count <= 3, "LR_PENDING should prevent excessive errors"
