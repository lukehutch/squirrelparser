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

    # ===========================================================================
    # Additional tests for transparent rule skipping and repetition bounds
    # ===========================================================================

    def test_bpr01_repetition_stops_at_sibling_terminal(self):
        # OneOrMore should stop when sibling terminal can match
        result = test_parse('S <- "x"+ "Y" ;', 'xxY')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have no errors"

    def test_bpr02_repetition_stops_at_sibling_after_error(self):
        # After recovering from error, repetition should still respect sibling
        result = test_parse('S <- "x"+ "Y" ;', 'xZxY')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error (Z)"
        assert 'Z' in result.skipped_strings, "should skip Z"
        assert 'Y' not in result.skipped_strings, "should NOT skip Y"

    def test_bpr03_repetition_stops_at_optional_sibling(self):
        # Repetition should stop when optional sibling can match
        result = test_parse('S <- "x"+ "!"? ;', 'xx!')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have no errors"

    def test_bpr04_repetition_with_error_stops_at_optional_sibling(self):
        # After error recovery, repetition should stop at optional sibling
        result = test_parse('S <- "x"+ "!"? ;', 'xZx!')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error (Z)"
        assert '!' not in result.skipped_strings, "should NOT skip !"

    def test_wbs01_bracket_bound_through_whitespace(self):
        # The "]" should be the effective bound, not WS
        grammar = '''
            S <- "[" WS Items WS "]" ;
            Items <- Item* ;
            Item <- "x" ;
            ~WS <- [ ]* ;
        '''
        result = test_parse(grammar, '[xx]')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have no errors"

    def test_wbs03_bracket_bound_with_error_before_close(self):
        # Error recovery should stop at "]", not consume it
        grammar = '''
            S <- "[" WS Items WS "]" ;
            Items <- Item* ;
            Item <- "x" ;
            ~WS <- [ ]* ;
        '''
        result = test_parse(grammar, '[xZx]')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error (Z)"
        assert ']' not in result.skipped_strings, "should NOT skip ]"

    def test_als01_simple_array_valid(self):
        grammar = '''
            S <- "[" (V ("," V)*)? "]" ;
            V <- [0-9]+ ;
        '''
        result = test_parse(grammar, '[1,2,3]')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have no errors"

    def test_als03_array_with_error_in_middle(self):
        # Error between values should be recovered, ] should still match
        grammar = '''
            S <- "[" WS (V (WS "," WS V)*)? WS "]" ;
            V <- [0-9]+ ;
            ~WS <- [ ]* ;
        '''
        result = test_parse(grammar, '[1,2X,3]')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error (X)"
        assert 'X' in result.skipped_strings, "should skip X"
        assert ']' not in result.skipped_strings, "should NOT skip ]"

    def test_als06_nested_arrays(self):
        # Nested arrays - inner ] should not be consumed by outer repetition
        grammar = '''
            S <- "[" WS (V (WS "," WS V)*)? WS "]" ;
            V <- S / [0-9]+ ;
            ~WS <- [ ]* ;
        '''
        result = test_parse(grammar, '[[1,2],3]')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have no errors"

    def test_rdr01_ref_to_whitespace_skipped(self):
        # Transparent WS should be skipped, non-transparent RBRACKET should be bound
        grammar = '''
            S <- "[" WS Items WS RBRACKET ;
            Items <- Item* ;
            Item <- "x" ;
            ~WS <- [ ]* ;
            RBRACKET <- "]" ;
        '''
        result = test_parse(grammar, '[xZx]')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error (Z)"
        assert ']' not in result.skipped_strings, "should NOT skip ]"

    def test_rsb01_no_trailing_skip_past_delimiter(self):
        # Trailing garbage recovery should stop at delimiter
        grammar = '''
            S <- "[" Items "]" ;
            Items <- "x"+ ;
        '''
        result = test_parse(grammar, '[xZ]')
        assert result.ok is True, "should succeed"
        assert ']' not in result.skipped_strings, "should NOT skip ]"

    def test_ctr01_charset_repetition_no_recovery(self):
        # CharSet repetition should NOT try to skip over non-matching content
        grammar = '''
            S <- [a-z]+ "!" ;
        '''
        result = test_parse(grammar, 'abXcd!')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"

    def test_ctr03_complex_subclause_does_recovery(self):
        # Repetition of complex clauses (Seq) SHOULD do recovery
        grammar = '''
            S <- ("ab")+ "!" ;
        '''
        result = test_parse(grammar, 'abXab!')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error (X)"
        assert '!' not in result.skipped_strings, "should NOT skip !"

    # ===========================================================================
    # Additional tests to match Dart test coverage
    # ===========================================================================

    def test_bpr05_nested_repetition_respects_outer_bound(self):
        grammar = '''
            S <- "[" Items "]" ;
            Items <- Item* ;
            Item <- "x" ;
        '''
        result = test_parse(grammar, '[xx]')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have no errors"

    def test_bpr06_nested_repetition_with_error_respects_bound(self):
        grammar = '''
            S <- "[" Items "]" ;
            Items <- Item* ;
            Item <- "x" ;
        '''
        result = test_parse(grammar, '[xZx]')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error (Z)"
        assert ']' not in result.skipped_strings, "should NOT skip ]"

    def test_wbs02_bracket_bound_with_actual_whitespace(self):
        grammar = '''
            S <- "[" WS Items WS "]" ;
            Items <- (WS Item)* ;
            Item <- "x" ;
            ~WS <- [ ]* ;
        '''
        result = test_parse(grammar, '[ x x ]')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have no errors"

    def test_wbs04_brace_bound_through_whitespace(self):
        grammar = '''
            S <- "{" WS Items WS "}" ;
            Items <- Item* ;
            Item <- "x" ;
            ~WS <- [ ]* ;
        '''
        result = test_parse(grammar, '{xZx}')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error (Z)"
        assert '}' not in result.skipped_strings, "should NOT skip }"

    def test_wbs05_multiple_whitespace_layers(self):
        grammar = '''
            S <- "[" WS1 WS2 Items WS1 WS2 "]" ;
            Items <- Item* ;
            Item <- "x" ;
            ~WS1 <- [ ]* ;
            ~WS2 <- [\t]* ;
        '''
        result = test_parse(grammar, '[xZx]')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error (Z)"
        assert ']' not in result.skipped_strings, "should NOT skip ]"

    def test_als02_array_with_whitespace_valid(self):
        grammar = '''
            S <- "[" WS (V (WS "," WS V)*)? WS "]" ;
            V <- [0-9]+ ;
            ~WS <- [ ]* ;
        '''
        result = test_parse(grammar, '[ 1 , 2 , 3 ]')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have no errors"

    def test_rdr02_multiple_refs_whitespace_all_skipped(self):
        grammar = '''
            S <- "[" SP TAB Items SP TAB RBRACKET ;
            Items <- Item* ;
            Item <- "x" ;
            ~SP <- [ ]* ;
            ~TAB <- [\t]* ;
            RBRACKET <- "]" ;
        '''
        result = test_parse(grammar, '[xZx]')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error (Z)"
        assert ']' not in result.skipped_strings, "should NOT skip ]"

    def test_rsb02_recovery_scan_stops_at_delimiter(self):
        grammar = '''
            S <- "[" Items "]" ;
            Items <- ("ab")+ ;
        '''
        result = test_parse(grammar, '[abZ]')
        assert result.ok is True, "should succeed"
        assert ']' not in result.skipped_strings, "should NOT skip ]"

    def test_rsb03_multiple_delimiters_nested(self):
        grammar = '''
            S <- "[" Inner "]" ;
            Inner <- "{" Items "}" ;
            Items <- "x"+ ;
        '''
        result = test_parse(grammar, '[{xZ}]')
        assert result.ok is True, "should succeed"
        assert '}' not in result.skipped_strings, "should NOT skip }"
        assert ']' not in result.skipped_strings, "should NOT skip ]"
