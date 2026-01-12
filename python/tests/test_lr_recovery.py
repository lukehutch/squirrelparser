# ===========================================================================
# SECTION 13: LEFT RECURSION ERROR RECOVERY
# ===========================================================================

from .test_utils import test_parse
from squirrelparser import squirrel_parse_pt

# directLR grammar for error recovery tests
DIRECT_LR = """
    S <- E ;
    E <- E "+n" / "n" ;
"""

# precedenceLR grammar for error recovery tests
PRECEDENCE_LR = """
    S <- E ;
    E <- E "+" T / E "-" T / T ;
    T <- T "*" F / T "/" F / F ;
    F <- "(" E ")" / "n" ;
"""


class TestLRRecovery:
    """Error recovery in direct LR grammar."""

    def test_lr_recovery_01_leading_error(self):
        """Input '+n+n+n+' starts with '+' which is invalid (need 'n' first)
        and ends with '+' which is also invalid (need 'n' after)"""
        r = test_parse(DIRECT_LR, '+n+n+n+')
        # This should fail because we can't recover a valid parse
        # The leading '+' prevents any initial 'n' match
        assert r.ok is False, "should fail (leading + is unrecoverable)"

    def test_lr_recovery_02_internal_error(self):
        """Input 'n+Xn+n' has garbage 'X' between + and n
        '+n' is a 2-char terminal, so 'n+X' doesn't match '+n'
        Grammar can only match 'n' at start, rest is captured as error"""
        r = test_parse(DIRECT_LR, 'n+Xn+n')
        assert r.ok is True, "should capture trailing as error"
        assert r.error_count == 1, "should have 1 error (unmatched +Xn+n)"

    def test_lr_recovery_03_trailing_junk(self):
        """Input 'n+n+nXXX' has trailing garbage
        With new invariant, trailing is captured as error in parse tree"""
        r = test_parse(DIRECT_LR, 'n+n+nXXX')
        assert r.ok is True, "should succeed with trailing captured"
        assert r.error_count == 1, "should have 1 error (trailing XXX)"
        assert any('XXX' in s for s in r.skipped_strings), "should capture XXX"


class TestPrecedenceGrammarRecovery:
    """Error recovery in precedence grammar."""

    def test_lr_recovery_04_missing_operand(self):
        """Input 'n+*n' has missing operand between + and *
        Parser recovers by skipping the extra '+' to parse as 'n*n'"""
        r = test_parse(PRECEDENCE_LR, 'n+*n')
        assert r.ok is True, "should recover by skipping +"
        assert r.error_count == 1, "one error: skip +"
        assert r.skipped_strings == ['+']

    def test_lr_recovery_05_double_op(self):
        """Input 'n++n' has double operator
        Parser recovers by skipping the extra '+' to parse as 'n+n'"""
        r = test_parse(PRECEDENCE_LR, 'n++n')
        assert r.ok is True, "should recover by skipping +"
        assert r.error_count == 1, "one error: skip +"
        assert r.skipped_strings == ['+']

    def test_lr_recovery_06_unclosed_paren(self):
        """Input '(n+n' has unclosed paren"""
        parse_result = squirrel_parse_pt(
            grammar_spec=PRECEDENCE_LR,
            top_rule_name='S',
            input='(n+n',
        )
        result = parse_result.root
        # With recovery, should insert missing ')'
        assert not result.is_mismatch, "should succeed with recovery"

    def test_lr_recovery_07_extra_close_paren(self):
        """Input 'n+n)' has extra close paren
        With new invariant, trailing is captured as error"""
        r = test_parse(PRECEDENCE_LR, 'n+n)')
        assert r.ok is True, "should succeed with trailing captured"
        assert r.error_count == 1, "should have 1 error (trailing ))"
        assert any(')' in s for s in r.skipped_strings), "should capture )"


class TestRefLRMasking:
    """Ref LR Masking Tests.

    F1-LR-05 case: T -> T*F | F. Input "n+n*Xn".
    Error is at 'X'.
    Optimal recovery: T matches "n", * matches "*", F fails on "X". F recovery skips "X" -> "n". Total 1 error.
    Suboptimal (current): T fails. E matches "n+n". E recursion fails. E recovery skips "*X". Total 2 errors.
    """

    GRAMMAR = """
        E <- E "+" T / T ;
        T <- T "*" F / F ;
        F <- "(" E ")" / "n" ;
    """

    def test_mask_01_error_at_t_level_after_star(self):
        """Current behavior: 2 errors (recovery at E level).
        Optimal behavior (future goal): 1 error (recovery at F level).
        This is a known limitation: Ref can mask deeper recovery opportunities.
        The test expects current behavior, not optimal."""
        r = test_parse(self.GRAMMAR, 'n+n*Xn', 'E')
        assert r.ok is True, "should recover"
        assert r.error_count == 2, "current: 2 errors (suboptimal, but correct)"
        assert any('*' in s or 'X' in s for s in r.skipped_strings), "should skip * and/or X"
