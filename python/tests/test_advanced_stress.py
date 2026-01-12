"""
ADVANCED STRESS TESTS FOR SQUIRREL PARSER RECOVERY

These tests attempt to expose edge cases, subtle bugs, and potential
violations of the three invariants (Completeness, Isolation, Minimality).
"""

from tests.test_utils import test_parse


# ===========================================================================
# SECTION A: PHASE ISOLATION ATTACKS
# ===========================================================================

class TestPhaseIsolationAttacks:
    def test_iso_01_probe_during_recovery_probe(self):
        grammar = '''
            S <- A* B ;
            A <- "a"+ "x" ;
            B <- "b" "z" ;
        '''
        r = test_parse(grammar, 'aaXxbz')
        assert r.ok, "nested probe should not poison cache"

    def test_iso_02_recovery_version_overflow(self):
        grammar = 'S <- "ab"+ ;'
        input_str = 'ab' + ''.join('Xab' for _ in range(50))
        r = test_parse(grammar, input_str)
        assert r.ok, "many errors should not overflow version"
        assert r.error_count == 50, "should count all 50 errors"

    def test_iso_03_alternating_probe_match(self):
        grammar = '''
            S <- A* B* "end" ;
            A <- "a" ;
            B <- "a" ;
        '''
        r = test_parse(grammar, 'aaaXend')
        assert r.ok, "ambiguous probes should resolve correctly"

    def test_iso_04_complete_result_reuse_after_lr(self):
        grammar = '''
            S <- A E ;
            A <- "a" ;
            E <- E "+" "a" / "a" ;
        '''
        r = test_parse(grammar, 'aa+a')
        assert r.ok, "complete result should be isolated from LR"
        assert r.error_count == 0, "clean parse"

    def test_iso_05_mismatch_cache_across_phases(self):
        grammar = '''
            S <- "abc" "xyz" / "ab" "z" ;
        '''
        r = test_parse(grammar, 'abXz')
        assert r.ok, "Phase 1 mismatch should not block Phase 2"


# ===========================================================================
# SECTION B: LEFT RECURSION EDGE CASES
# ===========================================================================

class TestLeftRecursionEdgeCases:
    def test_lr_edge_01_triple_nested_lr(self):
        grammar = '''
            A <- A "+" B / B ;
            B <- B "*" C / C ;
            C <- C "-" "n" / "n" ;
        '''
        r = test_parse(grammar, 'n+n*n-Xn', 'A')
        assert r.ok, "triple LR should recover"

    def test_lr_edge_02_lr_inside_repetition(self):
        grammar = '''
            S <- E+ ;
            E <- E "+" "n" / "n" ;
        '''
        r = test_parse(grammar, 'n+nXn+n')
        assert r.ok, "LR inside repetition should work"

    def test_lr_edge_03_lr_with_lookahead(self):
        grammar = '''
            E <- E "+" T / T ;
            T <- !"+" "n" ;
        '''
        r = test_parse(grammar, 'n+Xn', 'E')
        assert r.ok, "LR with lookahead should recover"

    def test_lr_edge_04_mutual_lr(self):
        grammar = '''
            A <- B "a" / "x" ;
            B <- A "b" / "y" ;
        '''
        r = test_parse(grammar, 'ybaXba', 'A')
        assert r.ok, "mutual LR should recover"

    def test_lr_edge_05_lr_zero_length_between(self):
        grammar = '''
            E <- E " "? "+" "n" / "n" ;
        '''
        r = test_parse(grammar, 'n +Xn', 'E')
        assert r.ok, "LR with optional should recover"

    def test_lr_edge_06_lr_empty_base(self):
        grammar = '''
            E <- E "+" "n" / "n"? ;
        '''
        # This is a pathological grammar - empty base allows infinite LR
        # Parser should handle gracefully
        test_parse(grammar, '+n+n', 'E')
        # May fail or succeed with errors - just shouldn't infinite loop
        assert True, "should not infinite loop"


# ===========================================================================
# SECTION C: RECOVERY MINIMALITY ATTACKS
# ===========================================================================

class TestRecoveryMinimalityAttacks:
    def test_min_01_multiple_valid_recoveries(self):
        grammar = '''
            S <- "a" "b" "c" / "a" "c" ;
        '''
        r = test_parse(grammar, 'aXc')
        assert r.ok, "should find recovery"
        assert r.error_count == 1, "should choose minimal recovery"

    def test_min_02_grammar_deletion_vs_input_skip(self):
        grammar = 'S <- "a" "b" "c" "d" ;'
        r = test_parse(grammar, 'aXd')
        assert not r.ok, "should fail (requires mid-parse grammar deletion)"

        r2 = test_parse(grammar, 'abc')
        assert r2.ok, "should succeed with EOF grammar deletion"
        assert r2.error_count == 1, 'delete "d" at EOF'

    def test_min_03_greedy_repetition_interaction(self):
        grammar = 'S <- "a"+ "b" ;'
        r = test_parse(grammar, 'aaaaXb')
        assert r.ok, "repetition should respect bounds"
        assert r.error_count == 1, "should skip only X"

    def test_min_04_nested_seq_recovery(self):
        grammar = '''
            S <- "(" ("a" "b") ")" ;
        '''
        r = test_parse(grammar, '(aXb)')
        assert r.ok, "inner Seq should recover by skipping X"
        assert r.error_count == 1, "should skip only X"

        r2 = test_parse(grammar, '(aX)')
        assert not r2.ok, "should fail (requires mid-parse grammar deletion)"

    def test_min_05_recovery_position_optimization(self):
        grammar = 'S <- "aaa" "bbb" ;'
        r = test_parse(grammar, 'aaXbbb')
        assert not r.ok, "should fail (requires mid-parse grammar deletion)"


# ===========================================================================
# SECTION D: COMPLETENESS ACCURACY ATTACKS
# ===========================================================================

class TestCompletenessAccuracyAttacks:
    def test_comp_01_nested_incomplete(self):
        grammar = '''
            S <- A "z" ;
            A <- B "y" ;
            B <- C "x" ;
            C <- "a"* ;
        '''
        r = test_parse(grammar, 'aaaQxyz')
        assert r.ok, "deeply nested incomplete should trigger recovery"
        assert r.error_count == 1, "should skip Q"

    def test_comp_02_optional_inside_repetition(self):
        grammar = '''
            S <- ("a" "b"?)+ "z" ;
        '''
        r = test_parse(grammar, 'aabXaz')
        assert r.ok, "should recover"

    def test_comp_03_first_alternative_incomplete(self):
        grammar = '''
            S <- "a"* "x" / "a"* "y" ;
        '''
        r = test_parse(grammar, 'aaaQy')
        assert r.ok, "should recover"

    def test_comp_04_complete_zero_length(self):
        grammar = 'S <- "x"* "a" ;'
        r = test_parse(grammar, 'a')
        assert r.ok, "zero-length complete should work"
        assert r.error_count == 0, "clean parse"

    def test_comp_05_incomplete_at_eof(self):
        grammar = 'S <- "a"+ "z" ;'
        r = test_parse(grammar, 'aaa')
        assert r.ok, "should delete missing z"


# ===========================================================================
# SECTION E: CACHE COHERENCE STRESS TESTS
# ===========================================================================

class TestCacheCoherenceStressTests:
    def test_cache_01_same_clause_multiple_positions(self):
        grammar = '''
            S <- X "+" X ;
            X <- "n" ;
        '''
        r = test_parse(grammar, 'nQn')
        assert not r.ok, "requires mid-parse grammar deletion"

        r2 = test_parse(grammar, 'n+Xn')
        assert r2.ok, "same clause at different positions"
        assert r2.error_count == 1, "skip X between + and n"

    def test_cache_02_diamond_dependency(self):
        grammar = '''
            S <- A B ;
            A <- "a" C ;
            B <- "b" C ;
            C <- "c" ;
        '''
        r = test_parse(grammar, 'acXbc')
        assert r.ok, "diamond dependency should work"

    def test_cache_03_repeated_lr_at_same_pos(self):
        grammar = '''
            S <- E ";" E ;
            E <- E "+" "n" / "n" ;
        '''
        r = test_parse(grammar, 'n+n;n+Xn')
        assert r.ok, "repeated LR should work"

    def test_cache_04_interleaved_lr_and_non_lr(self):
        grammar = '''
            S <- E "," F "," E ;
            E <- E "+" "n" / "n" ;
            F <- "xyz" ;
        '''
        r = test_parse(grammar, 'n+n,xyz,n+Xn')
        assert r.ok, "interleaved LR/non-LR should work"

    def test_cache_05_rapid_phase_switching(self):
        grammar = '''
            S <- A* B* C* "end" ;
            A <- "a" ;
            B <- "b" ;
            C <- "c" ;
        '''
        r = test_parse(grammar, 'aaaXbbbYcccZend')
        assert r.ok, "rapid phase switching should work"


# ===========================================================================
# SECTION F: PATHOLOGICAL GRAMMARS
# ===========================================================================

class TestPathologicalGrammars:
    @staticmethod
    def _build_deep_first(depth: int) -> str:
        if depth == 0:
            return '"target"'
        return f'"x" / ({TestPathologicalGrammars._build_deep_first(depth - 1)})'

    @staticmethod
    def _build_deep_seq(depth: int) -> str:
        if depth == 0:
            return '"x"'
        return f'"a" ({TestPathologicalGrammars._build_deep_seq(depth - 1)})'

    def test_path_01_deeply_nested_first(self):
        grammar = f'S <- {self._build_deep_first(20)} ;'
        r = test_parse(grammar, 'target')
        assert r.ok, "deep First should work"

    def test_path_02_deeply_nested_seq(self):
        grammar = f'S <- ({self._build_deep_seq(20)}) "end" ;'
        input_str = 'a' * 20 + 'Qx' + 'end'
        r = test_parse(grammar, input_str)
        assert r.ok, "deep Seq should recover"

    def test_path_03_many_alternatives(self):
        alts = ' / '.join(f'"opt{i}"' for i in range(50))
        grammar = f'S <- {alts} / "target" ;'
        r = test_parse(grammar, 'target')
        assert r.ok, "many alternatives should work"

    def test_path_04_wide_seq(self):
        elems = ' '.join(f'"{chr(97 + (i % 26))}"' for i in range(30))
        grammar = f'S <- {elems} ;'
        input_str = ''.join(chr(97 + (i % 26)) for i in range(30))
        err_input = input_str[:15] + 'X' + input_str[15:]
        r = test_parse(grammar, err_input)
        assert r.ok, "wide Seq should recover"

    def test_path_05_repetition_of_repetition(self):
        grammar = 'S <- ("a"+)+ ;'
        r = test_parse(grammar, 'aaaXaaa')
        assert r.ok, "nested repetition should work"


# ===========================================================================
# SECTION G: REAL-WORLD GRAMMAR PATTERNS
# ===========================================================================

class TestRealWorldGrammarPatterns:
    def test_real_01_json_like_array(self):
        grammar = '''
            Array <- "[" Elements? "]" ;
            Elements <- Value ("," Value)* ;
            Value <- Array / "n" ;
        '''
        r = test_parse(grammar, '[n n]', 'Array')
        assert r.ok, "should recover missing comma"

    def test_real_02_expression_with_parens(self):
        grammar = '''
            E <- E "+" T / T ;
            T <- T "*" F / F ;
            F <- "(" E ")" / "n" ;
        '''
        r = test_parse(grammar, '(n+n', 'E')
        assert r.ok, "should insert missing close paren"

    def test_real_03_statement_list(self):
        grammar = '''
            Program <- Stmt+ ;
            Stmt <- Expr ";" ;
            Expr <- "if" "(" Expr ")" Stmt / "x" ;
        '''
        r = test_parse(grammar, 'x x;', 'Program')
        assert r.ok, "should recover missing semicolon"

    def test_real_04_string_literal(self):
        grammar = 'S <- "\\"" [a-z]* "\\"" ;'
        r = test_parse(grammar, '"hello')
        assert r.ok, "should insert missing quote"

    def test_real_05_nested_blocks(self):
        grammar = '''
            Block <- "{" Stmt* "}" ;
            Stmt <- Block / "x" ";" ;
        '''
        r = test_parse(grammar, '{x;{x;Xx;}}', 'Block')
        assert r.ok, "nested blocks should recover"


# ===========================================================================
# SECTION H: EMERGENT INTERACTION TESTS
# ===========================================================================

class TestEmergentInteractionTests:
    def test_emerg_01_lr_with_bounded_rep_recovery(self):
        grammar = '''
            S <- E "end" ;
            E <- E "+" "n"+ / "n" ;
        '''
        r = test_parse(grammar, 'n+nXn+nnend')
        assert r.ok, "LR with bounded rep should work"

    def test_emerg_02_probe_triggers_lr(self):
        grammar = '''
            S <- "a"* E ;
            E <- E "+" "n" / "n" ;
        '''
        r = test_parse(grammar, 'aaXn+n')
        assert r.ok, "probe triggering LR should work"

    def test_emerg_03_recovery_resets_lr_expansion(self):
        grammar = '''
            S <- E ";" E ;
            E <- E "+" "n" / "n" ;
        '''
        r = test_parse(grammar, 'n+Xn;n+n+n')
        assert r.ok, "second LR should expand independently"
        assert r.error_count == 1, "only first E has error"

    def test_emerg_04_incomplete_propagation_through_lr(self):
        grammar = '''
            E <- E "+" T / T ;
            T <- "n" "x"* ;
        '''
        r = test_parse(grammar, 'nxx+nxQx', 'E')
        assert r.ok, "incomplete should propagate through LR"

    def test_emerg_05_cache_version_after_lr_recovery(self):
        grammar = '''
            S <- E ";" E ;
            E <- E "+" "n" / "n" ;
        '''
        r = test_parse(grammar, 'n+Xn+n;n+n')
        assert r.ok, "version should be correct after LR recovery"
