# ===========================================================================
# COMPLEX INTERACTIONS TESTS
# ===========================================================================
# These tests verify complex combinations of features working together.

from tests.test_utils import test_parse


class TestComplexInteractions:

    def test_complex01_lr_bound_recovery_all_together(self):
        # LR + bound propagation + recovery all working together (EMERG-01 verified)
        grammar = '''
            S <- E "end" ;
            E <- E "+" "n"+ / "n" ;
        '''
        result = test_parse(grammar, 'n+nXn+nnend')
        assert result.ok is True, "should succeed (FIX #9 bound propagation)"
        assert result.error_count > 0, "should have at least 1 error"
        assert 'X' in result.skipped_strings, "should skip X"
        # LR expands, OneOrMore with recovery, bound stops before 'end'

    def test_complex02_nested_first_with_different_recovery_costs(self):
        # Nested First, each with alternatives requiring different recovery
        grammar = '''
            S <- ("x" / "y") "z" / "a" ;
        '''
        result = test_parse(grammar, 'xXz')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should choose first alternative with recovery"
        # Outer First chooses first alternative (Seq)
        # Inner First chooses first alternative 'x'
        # Then skip X, match 'z'

    def test_complex03_recovery_version_overflow_verified(self):
        # Many recoveries to test version counter doesn't overflow
        input_str = 'ab' + ''.join(['Xab' for _ in range(50)])
        grammar = 'S <- "ab"+ ;'
        result = test_parse(grammar, input_str)
        assert result.ok is True, "should succeed (version counter handles 50+ recoveries)"
        assert result.error_count == 50, "should count all 50 errors"

    def test_complex04_probe_during_recovery(self):
        # ZeroOrMore uses probe while recovery is happening
        grammar = '''
            S <- "x"* ("y" / "z") ;
        '''
        result = test_parse(grammar, 'xXxz')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert 'X' in result.skipped_strings, "should skip X"
        # ZeroOrMore with recovery inside, probes to find 'z'

    def test_complex05_multiple_refs_same_rule_with_recovery(self):
        # Multiple Refs to same rule, each with independent recovery
        grammar = '''
            S <- A "+" A ;
            A <- "n" ;
        '''
        result = test_parse(grammar, 'nX+n')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        # First Ref('A') needs recovery, second Ref('A') is clean

    def test_complex06_deeply_nested_lr(self):
        # Multiple LR levels with recovery at different depths
        grammar = '''
            A <- A "a" B / B ;
            B <- B "b" "x" / "x" ;
        '''
        result = test_parse(grammar, 'xbXxaXxbx', 'A')
        assert result.ok is True, "should succeed"
        assert result.error_count == 2, "should have 2 errors (X's at both A and B levels)"

    def test_complex07_recovery_with_lookahead(self):
        # Recovery near lookahead assertions
        grammar = '''
            S <- "a" &"b" "b" "c" ;
        '''
        result = test_parse(grammar, 'aXbc')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert 'X' in result.skipped_strings, "should skip X"
        # After skipping X, FollowedBy(b) checks 'b' without consuming

    def test_complex08_recovery_in_negative_lookahead(self):
        # NotFollowedBy with recovery context
        grammar = '''
            S <- "a" !"x" "b" ;
        '''
        result = test_parse(grammar, 'ab')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # NotFollowedBy('x') succeeds (next is 'b', not 'x')

    def test_complex09_alternating_lr_and_repetition(self):
        # Grammar with both LR and repetitions at same level
        grammar = '''
            S <- E ";" "x"+ ;
            E <- E "+" "n" / "n" ;
        '''
        result = test_parse(grammar, 'n+n;xxx')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # E is left-recursive, then ';', then repetition

    def test_complex10_recovery_spanning_multiple_clauses(self):
        # Single error region that spans where multiple clauses would try to match
        grammar = '''
            S <- "a" "b" "c" "d" ;
        '''
        result = test_parse(grammar, 'aXYZbcd')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error (entire XYZ region)"
        assert 'XYZ' in result.skipped_strings, "should skip XYZ as single region"

    def test_complex11_ref_through_multiple_indirections(self):
        # A -> B -> C -> D, all Refs
        grammar = '''
            A <- B ;
            B <- C ;
            C <- D ;
            D <- "x" ;
        '''
        result = test_parse(grammar, 'x', 'A')
        assert result.ok is True, "should succeed (multiple Ref indirections)"
        assert result.error_count == 0, "should have 0 errors"

    def test_complex12_circular_refs_with_recovery(self):
        # Mutual recursion with simple clean input
        grammar = '''
            S <- A "end" ;
            A <- "a" B / "a" ;
            B <- "b" A / "b" ;
        '''
        result = test_parse(grammar, 'ababend', 'S')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors (clean parse)"
        # Mutual recursion: A -> B -> A -> B (abab)

    def test_complex13_all_clause_types_in_one_grammar(self):
        # Every clause type in one complex grammar
        grammar = '''
            S <- A "opt"? "z"* ("f1" / "f2") &"end" "end" ;
            A <- A "+" "a" / "a" ;
        '''
        result = test_parse(grammar, 'a+aoptzzzf1end', 'S')
        assert result.ok is True, "should succeed (all clause types work together)"
        assert result.error_count == 0, "should have 0 errors"

    def test_complex14_recovery_at_every_level_of_deep_nesting(self):
        # Error at each level of deep nesting, all recover
        grammar = '''
            S <- "a" "b" "c" "d" ;
        '''
        result = test_parse(grammar, 'aXbYcZd')
        assert result.ok is True, "should succeed"
        assert result.error_count == 3, "should have 3 errors"
        # Error at each nesting level

    def test_complex15_performance_large_grammar(self):
        # Large grammar with many rules
        rules = '\n'.join([
            f'Rule{i} <- "opt_{str(i).zfill(3)}" ;'
            for i in range(50)
        ])
        alternatives = ' / '.join([f'Rule{i}' for i in range(50)])
        grammar = f'''
            {rules}
            S <- {alternatives} ;
        '''

        result = test_parse(grammar, 'opt_025', 'S')
        assert result.ok is True, "should succeed (large grammar with 50 rules)"
