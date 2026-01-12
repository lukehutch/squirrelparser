# ===========================================================================
# BOUND PROPAGATION TESTS (FIX #9 Verification)
# ===========================================================================
# These tests verify that bounds propagate through arbitrary nesting levels
# to correctly stop repetitions before consuming delimiters.

from tests.test_utils import test_parse


class TestBoundPropagation:

    def test_bp01_direct_repetition(self):
        # Baseline: Bound with direct Repetition child (was already working)
        result = test_parse('S <- "x"+ "end" ;', 'xxxxend')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_bp02_through_ref(self):
        # FIX #9: Bound propagates through Ref
        grammar = '''
            S <- A "end" ;
            A <- "x"+ ;
        '''
        result = test_parse(grammar, 'xxxxend')
        assert result.ok is True, "should succeed (bound through Ref)"
        assert result.error_count == 0, "should have 0 errors"

    def test_bp03_through_nested_refs(self):
        # FIX #9: Bound propagates through multiple Refs
        grammar = '''
            S <- A "end" ;
            A <- B ;
            B <- "x"+ ;
        '''
        result = test_parse(grammar, 'xxxxend')
        assert result.ok is True, "should succeed (bound through 2 Refs)"
        assert result.error_count == 0, "should have 0 errors"

    def test_bp04_through_first(self):
        # FIX #9: Bound propagates through First alternatives
        grammar = '''
            S <- A "end" ;
            A <- "x"+ / "y"+ ;
        '''
        result = test_parse(grammar, 'xxxxend')
        assert result.ok is True, "should succeed (bound through First)"
        assert result.error_count == 0, "should have 0 errors"

    def test_bp05_left_recursive_with_repetition(self):
        # FIX #9: The EMERG-01 case - bound through LR + First + Seq + Repetition
        grammar = '''
            S <- E "end" ;
            E <- E "+" "n"+ / "n" ;
        '''
        result = test_parse(grammar, 'n+nnn+nnend')
        assert result.ok is True, "should succeed (bound through LR)"
        assert result.error_count == 0, "should have 0 errors"

    def test_bp06_with_recovery_inside_bounded_rep(self):
        # FIX #9 + recovery: Bound propagates AND recovery works inside repetition
        grammar = '''
            S <- A "end" ;
            A <- "ab"+ ;
        '''
        result = test_parse(grammar, 'abXabYabend')
        assert result.ok is True, "should succeed"
        assert result.error_count == 2, "should have 2 errors (X and Y)"
        assert 'X' in result.skipped_strings, "should skip X"
        assert 'Y' in result.skipped_strings, "should skip Y"

    def test_bp07_multiple_bounds_nested_seq(self):
        # Multiple bounds in nested Seq structures
        grammar = '''
            S <- A ";" B "end" ;
            A <- "x"+ ;
            B <- "y"+ ;
        '''
        result = test_parse(grammar, 'xxxx;yyyyend')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # A stops at ';', B stops at 'end'

    def test_bp08_bound_vs_eof(self):
        # Without explicit bound, should consume until EOF
        result = test_parse('S <- "x"+ ;', 'xxxx')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # No bound, so consumes all x's

    def test_bp09_zeoormore_with_bound(self):
        # Bound applies to ZeroOrMore too
        result = test_parse('S <- "x"* "end" ;', 'end')
        assert result.ok is True, "should succeed (ZeroOrMore matches 0)"
        assert result.error_count == 0, "should have 0 errors"

    def test_bp10_complex_nesting(self):
        # Deeply nested: Ref -> First -> Seq -> Ref -> Repetition
        grammar = '''
            S <- A "end" ;
            A <- "a" B / "fallback" ;
            B <- "x"+ ;
        '''
        result = test_parse(grammar, 'axxxxend')
        assert result.ok is True, "should succeed (bound through complex nesting)"
        assert result.error_count == 0, "should have 0 errors"
