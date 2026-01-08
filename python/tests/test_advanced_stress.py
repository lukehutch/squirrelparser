"""
ADVANCED STRESS TESTS FOR SQUIRREL PARSER RECOVERY
These tests attempt to expose edge cases, subtle bugs, and potential
violations of the three invariants (Completeness, Isolation, Minimality).
"""
from squirrelparser import Str, CharRange, Seq, First, OneOrMore, ZeroOrMore, Optional, NotFollowedBy, Ref, Clause
from tests.test_utils import parse


class TestPhaseIsolationAttacks:
    """Phase Isolation Attacks

    Tests that attempt to violate Invariant II by creating cache pollution
    scenarios between Phase 1, Phase 2, and probe() calls.
    """

    def test_iso_01_probe_during_recovery_probe(self) -> None:
        """ISO-01-probe-during-recovery-probe"""
        # Nested probe scenario: recovery calls probe, which may trigger
        # another bounded repetition that also calls probe.
        grammar = {
            'S': Seq(ZeroOrMore(Ref('A')), Ref('B')),
            'A': Seq(OneOrMore(Str('a')), Str('x')),
            'B': Seq(Str('b'), Str('z')),
        }
        # 'A' has inner OneOrMore which uses bound checking via probe
        # S's ZeroOrMore also uses probe for bounds
        ok, err, skip = parse(grammar, 'aaXxbz')
        assert ok, 'nested probe should not poison cache'

    def test_iso_02_recovery_version_overflow(self) -> None:
        """ISO-02-recovery-version-overflow"""
        # Many small errors to increment recoveryVersion many times
        # Tests that version counter doesn't wrap or cause issues
        grammar = {
            'S': OneOrMore(Str('ab')),
        }
        # FIX #10: With first-iteration recovery, input "aXaXaX...ab" skips all the way to first 'ab'
        # This counts as 1 error (entire skipped region). To test multiple errors, use "abXabXabX..."
        input_str = 'ab' + ''.join('Xab' for _ in range(50))
        ok, err, skip = parse(grammar, input_str)
        assert ok, 'many errors should not overflow version'
        assert err == 50, 'should count all 50 errors'

    def test_iso_03_alternating_probe_match(self) -> None:
        """ISO-03-alternating-probe-match"""
        # Alternate between probe and real match at same position
        grammar = {
            'S': Seq(
                ZeroOrMore(Ref('A')),
                ZeroOrMore(Ref('B')),
                Str('end'),
            ),
            'A': Str('a'),
            'B': Str('a'),  # Same as A - creates ambiguity
        }
        # Both ZeroOrMore will probe 'a' positions
        ok, err, skip = parse(grammar, 'aaaXend')
        assert ok, 'ambiguous probes should resolve correctly'

    def test_iso_04_complete_result_reuse_after_lr(self) -> None:
        """ISO-04-complete-result-reuse-after-lr"""
        # A complete result at position P, then LR expansion that touches P
        grammar = {
            'S': Seq(Ref('A'), Ref('E')),
            'A': Str('a'),
            'E': First(
                Seq(Ref('E'), Str('+'), Str('a')),
                Str('a')
            ),
        }
        # 'A' matches 'a' (complete). Then E starts LR at position 1.
        # E should not reuse A's result at position 0.
        ok, err, skip = parse(grammar, 'aa+a')
        assert ok, 'complete result should be isolated from LR'
        assert err == 0, 'clean parse'

    def test_iso_05_mismatch_cache_across_phases(self) -> None:
        """ISO-05-mismatch-cache-across-phases"""
        # Ensure mismatch in Phase 1 doesn't block recovery in Phase 2
        grammar = {
            'S': First(
                Seq(Str('abc'), Str('xyz')),
                Seq(Str('ab'), Str('z')),
            ),
        }
        # Phase 1: First alternative fails at 'Xz', second fails at 'X'
        # Phase 2: Should skip 'X' and match second alternative
        ok, err, skip = parse(grammar, 'abXz')
        assert ok, 'Phase 1 mismatch should not block Phase 2'


class TestLeftRecursionEdgeCases:
    """Left Recursion Edge Cases"""

    def test_lr_edge_01_triple_nested_lr(self) -> None:
        """LR-EDGE-01-triple-nested-lr"""
        # Three levels of left recursion
        grammar = {
            'A': First(
                Seq(Ref('A'), Str('+'), Ref('B')),
                Ref('B')
            ),
            'B': First(
                Seq(Ref('B'), Str('*'), Ref('C')),
                Ref('C')
            ),
            'C': First(
                Seq(Ref('C'), Str('-'), Str('n')),
                Str('n')
            ),
        }
        # Error at deepest level
        ok, err, skip = parse(grammar, 'n+n*n-Xn', 'A')
        assert ok, 'triple LR should recover'

    def test_lr_edge_02_lr_inside_repetition(self) -> None:
        """LR-EDGE-02-lr-inside-repetition"""
        # Left recursion inside a repetition
        grammar = {
            'S': OneOrMore(Ref('E')),
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
        }
        # Two LR expressions separated by space
        ok, err, skip = parse(grammar, 'n+nXn+n')
        assert ok, 'LR inside repetition should work'

    def test_lr_edge_03_lr_with_lookahead(self) -> None:
        """LR-EDGE-03-lr-with-lookahead"""
        # Left recursion with negative lookahead
        grammar = {
            'E': First(
                Seq(Ref('E'), Str('+'), Ref('T')),
                Ref('T'),
            ),
            'T': Seq(NotFollowedBy(Str('+')), Str('n')),
        }
        ok, err, skip = parse(grammar, 'n+Xn', 'E')
        assert ok, 'LR with lookahead should recover'

    def test_lr_edge_04_mutual_lr(self) -> None:
        """LR-EDGE-04-mutual-lr"""
        # Mutually recursive left recursion
        grammar = {
            'A': First(
                Seq(Ref('B'), Str('a')),
                Str('x')
            ),
            'B': First(
                Seq(Ref('A'), Str('b')),
                Str('y')
            ),
        }
        ok, err, skip = parse(grammar, 'ybaXba', 'A')
        assert ok, 'mutual LR should recover'

    def test_lr_edge_05_lr_zero_length_between(self) -> None:
        """LR-EDGE-05-lr-zero-length-between"""
        # LR with zero-length elements between recursive call and terminal
        grammar = {
            'E': First(
                Seq(Ref('E'), Optional(Str(' ')), Str('+'), Str('n')),
                Str('n'),
            ),
        }
        ok, err, skip = parse(grammar, 'n +Xn', 'E')
        assert ok, 'LR with optional should recover'

    def test_lr_edge_06_lr_empty_base(self) -> None:
        """LR-EDGE-06-lr-empty-base"""
        # LR where base case can be empty
        grammar = {
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Optional(Str('n')),  # Can match empty!
            ),
        }
        # This is a pathological grammar - empty base allows infinite LR
        # Parser should handle gracefully
        ok, err, skip = parse(grammar, '+n+n', 'E')
        # May fail or succeed with errors - just shouldn't infinite loop
        assert True, 'should not infinite loop'


class TestRecoveryMinimalityAttacks:
    """Recovery Minimality Attacks"""

    def test_min_01_multiple_valid_recoveries(self) -> None:
        """MIN-01-multiple-valid-recoveries"""
        # Multiple ways to recover - should choose minimal
        grammar = {
            'S': First(
                Seq(Str('a'), Str('b'), Str('c')),
                Seq(Str('a'), Str('c')),
            ),
        }
        # 'aXc' can recover by: skip X (1 error) or delete b, skip X (2 errors)
        ok, err, skip = parse(grammar, 'aXc')
        assert ok, 'should find recovery'
        assert err == 1, 'should choose minimal recovery'

    def test_min_02_grammar_deletion_vs_input_skip(self) -> None:
        """MIN-02-grammar-deletion-vs-input-skip"""
        # Test that mid-parse grammar deletion is blocked (Fix #8)
        grammar = {
            'S': Seq(Str('a'), Str('b'), Str('c'), Str('d')),
        }
        # 'aXd' would need: skip X (inputSkip=1) + delete b,c (grammarSkip=2)
        # But grammarSkip > 0 at non-EOF position violates Visibility Constraint
        ok, err, skip = parse(grammar, 'aXd')
        assert not ok, 'should fail (requires mid-parse grammar deletion)'

        # Valid alternative: grammar deletion at EOF
        ok2, err2, skip2 = parse(grammar, 'abc')
        assert ok2, 'should succeed with EOF grammar deletion'
        assert err2 == 1, 'delete "d" at EOF'

    def test_min_03_greedy_repetition_interaction(self) -> None:
        """MIN-03-greedy-repetition-interaction"""
        # Repetition might greedily consume too much, affecting minimality
        grammar = {
            'S': Seq(OneOrMore(Str('a')), Str('b')),
        }
        # 'aaaaXb' - should skip X, not consume 'b' into repetition
        ok, err, skip = parse(grammar, 'aaaaXb')
        assert ok, 'repetition should respect bounds'
        assert err == 1, 'should skip only X'

    def test_min_04_nested_seq_recovery(self) -> None:
        """MIN-04-nested-seq-recovery"""
        # Test nested Seq recovery with input skipping (no grammar deletion mid-parse)
        grammar = {
            'S': Seq(
                Str('('),
                Seq(Str('a'), Str('b')),
                Str(')')
            ),
        }
        # '(aXb)' - inner Seq can skip X without grammar deletion
        ok, err, skip = parse(grammar, '(aXb)')
        assert ok, 'inner Seq should recover by skipping X'
        assert err == 1, 'should skip only X'

        # '(aX)' would require deleting "b" mid-parse - should fail
        ok2, err2, skip2 = parse(grammar, '(aX)')
        assert not ok2, 'should fail (requires mid-parse grammar deletion)'

    def test_min_05_recovery_position_optimization(self) -> None:
        """MIN-05-recovery-position-optimization"""
        # Test structural integrity: cannot delete grammar elements mid-parse
        grammar = {
            'S': Seq(Str('aaa'), Str('bbb')),
        }
        # 'aaXbbb' - error breaks first element "aaa", cannot recover
        # Would require: skip "aaX" + delete "aaa" (grammarSkip=1 mid-parse)
        # This violates Visibility Constraint (Fix #8)
        ok, err, skip = parse(grammar, 'aaXbbb')
        assert not ok, 'should fail (requires mid-parse grammar deletion)'


class TestCompletenessAccuracyAttacks:
    """Completeness Accuracy Attacks"""

    def test_comp_01_nested_incomplete(self) -> None:
        """COMP-01-nested-incomplete"""
        # Deeply nested incomplete propagation
        grammar = {
            'S': Seq(Ref('A'), Str('z')),
            'A': Seq(Ref('B'), Str('y')),
            'B': Seq(Ref('C'), Str('x')),
            'C': ZeroOrMore(Str('a')),
        }
        # 'aaaQx...' - C matches 'aaa', then fails on Q
        # Incomplete must propagate through B -> A -> S
        ok, err, skip = parse(grammar, 'aaaQxyz')
        assert ok, 'deeply nested incomplete should trigger recovery'
        assert err == 1, 'should skip Q'

    def test_comp_02_optional_inside_repetition(self) -> None:
        """COMP-02-optional-inside-repetition"""
        # Optional inside repetition - incomplete tracking
        grammar = {
            'S': Seq(
                OneOrMore(Seq(Str('a'), Optional(Str('b')))),
                Str('z')
            ),
        }
        # 'aabXaz' - the Optional('b') failing on X should propagate
        ok, err, skip = parse(grammar, 'aabXaz')
        assert ok, 'should recover'

    def test_comp_03_first_alternative_incomplete(self) -> None:
        """COMP-03-first-alternative-incomplete"""
        # First alternative returns incomplete, should try next
        grammar = {
            'S': First(
                Seq(ZeroOrMore(Str('a')), Str('x')),
                Seq(ZeroOrMore(Str('a')), Str('y')),
            ),
        }
        # 'aaaQy' - first alt incomplete at Q, second should try
        ok, err, skip = parse(grammar, 'aaaQy')
        # In Phase 1, first returns incomplete. First should try second.
        # But PEG is ordered, so first failing means Seq fails.
        assert ok, 'should recover'

    def test_comp_04_complete_zero_length(self) -> None:
        """COMP-04-complete-zero-length"""
        # Zero-length match that is actually complete
        grammar = {
            'S': Seq(ZeroOrMore(Str('x')), Str('a')),
        }
        # ZeroOrMore matches empty at 'a' - this IS complete
        ok, err, skip = parse(grammar, 'a')
        assert ok, 'zero-length complete should work'
        assert err == 0, 'clean parse'

    def test_comp_05_incomplete_at_eof(self) -> None:
        """COMP-05-incomplete-at-eof"""
        # Incomplete result exactly at EOF
        grammar = {
            'S': Seq(OneOrMore(Str('a')), Str('z')),
        }
        # 'aaa' - OneOrMore matches, but 'z' expected at EOF
        ok, err, skip = parse(grammar, 'aaa')
        assert ok, 'should delete missing z'


class TestCacheCoherenceStressTests:
    """Cache Coherence Stress Tests"""

    def test_cache_01_same_clause_multiple_positions(self) -> None:
        """CACHE-01-same-clause-multiple-positions"""
        # Same clause referenced at multiple positions
        grammar = {
            'S': Seq(Ref('X'), Str('+'), Ref('X')),
            'X': Str('n'),
        }
        # Input 'nQn' has "Q" instead of "+", requires grammar deletion
        # Would need: skip "Q" (inputSkip) + delete "+" (grammarSkip=1)
        # This violates Visibility Constraint - cannot delete "+" mid-parse
        ok, err, skip = parse(grammar, 'nQn')
        assert not ok, 'requires mid-parse grammar deletion'

        # Test that same clause works at different positions when input is valid
        ok2, err2, skip2 = parse(grammar, 'n+Xn')
        assert ok2, 'same clause at different positions'
        assert err2 == 1, 'skip X between + and n'

    def test_cache_02_diamond_dependency(self) -> None:
        """CACHE-02-diamond-dependency"""
        # Diamond: S -> A -> C, S -> B -> C
        grammar = {
            'S': Seq(Ref('A'), Ref('B')),
            'A': Seq(Str('a'), Ref('C')),
            'B': Seq(Str('b'), Ref('C')),
            'C': Str('c'),
        }
        # C is referenced from both A and B
        ok, err, skip = parse(grammar, 'acXbc')
        assert ok, 'diamond dependency should work'

    def test_cache_03_repeated_lr_at_same_pos(self) -> None:
        """CACHE-03-repeated-lr-at-same-pos"""
        # Multiple LR rules starting at same position
        grammar = {
            'S': Seq(Ref('E'), Str(';'), Ref('E')),
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
        }
        # Two separate E parses starting at different positions
        ok, err, skip = parse(grammar, 'n+n;n+Xn')
        assert ok, 'repeated LR should work'

    def test_cache_04_interleaved_lr_and_non_lr(self) -> None:
        """CACHE-04-interleaved-lr-and-non-lr"""
        # Alternating between LR and non-LR clauses
        grammar = {
            'S': Seq(Ref('E'), Str(','), Ref('F'), Str(','), Ref('E')),
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
            'F': Str('xyz'),
        }
        ok, err, skip = parse(grammar, 'n+n,xyz,n+Xn')
        assert ok, 'interleaved LR/non-LR should work'

    def test_cache_05_rapid_phase_switching(self) -> None:
        """CACHE-05-rapid-phase-switching"""
        # Simulate rapid switching between recovery enabled/disabled
        # This happens naturally during recovery with probes
        grammar = {
            'S': Seq(
                ZeroOrMore(Ref('A')),
                ZeroOrMore(Ref('B')),
                ZeroOrMore(Ref('C')),
                Str('end'),
            ),
            'A': Str('a'),
            'B': Str('b'),
            'C': Str('c'),
        }
        # Each ZeroOrMore uses probe, causing phase switches
        ok, err, skip = parse(grammar, 'aaaXbbbYcccZend')
        assert ok, 'rapid phase switching should work'


class TestPathologicalGrammars:
    """Pathological Grammars"""

    def test_path_01_deeply_nested_first(self) -> None:
        """PATH-01-deeply-nested-first"""
        # Very deep First nesting
        def build_deep_first(depth: int, terminal: str) -> Clause:
            if depth == 0:
                return Str(terminal)
            return First(Str('x'), build_deep_first(depth - 1, terminal))

        grammar = {
            'S': build_deep_first(20, 'target'),
        }
        ok, err, skip = parse(grammar, 'target')
        assert ok, 'deep First should work'

    def test_path_02_deeply_nested_seq(self) -> None:
        """PATH-02-deeply-nested-seq"""
        # Very deep Seq nesting
        def build_deep_seq(depth: int) -> Clause:
            if depth == 0:
                return Str('x')
            return Seq(Str('a'), build_deep_seq(depth - 1))

        grammar = {
            'S': Seq(build_deep_seq(20), Str('end')),
        }
        input_str = 'a' * 20 + 'Qx' + 'end'
        ok, err, skip = parse(grammar, input_str)
        assert ok, 'deep Seq should recover'

    def test_path_03_many_alternatives(self) -> None:
        """PATH-03-many-alternatives"""
        # Many First alternatives
        alts = [Str(f'opt{i}') for i in range(50)]
        grammar = {
            'S': First(*alts, Str('target')),
        }
        ok, err, skip = parse(grammar, 'target')
        assert ok, 'many alternatives should work'

    def test_path_04_wide_seq(self) -> None:
        """PATH-04-wide-seq"""
        # Very wide Seq (many siblings)
        elems = [Str(chr(97 + (i % 26))) for i in range(30)]
        grammar = {
            'S': Seq(*elems),
        }
        # Insert error in middle
        input_str = ''.join(chr(97 + (i % 26)) for i in range(30))
        err_input = input_str[:15] + 'X' + input_str[15:]
        ok, err, skip = parse(grammar, err_input)
        assert ok, 'wide Seq should recover'

    def test_path_05_repetition_of_repetition(self) -> None:
        """PATH-05-repetition-of-repetition"""
        # Nested repetitions
        grammar = {
            'S': OneOrMore(OneOrMore(Str('a'))),
        }
        ok, err, skip = parse(grammar, 'aaaXaaa')
        assert ok, 'nested repetition should work'


class TestRealWorldGrammarPatterns:
    """Real-World Grammar Patterns"""

    def test_real_01_json_like_array(self) -> None:
        """REAL-01-json-like-array"""
        grammar = {
            'Array': Seq(Str('['), Optional(Ref('Elements')), Str(']')),
            'Elements': Seq(
                Ref('Value'),
                ZeroOrMore(Seq(Str(','), Ref('Value')))
            ),
            'Value': First(Ref('Array'), Str('n')),
        }
        # Missing comma
        ok, err, skip = parse(grammar, '[n n]', 'Array')
        assert ok, 'should recover missing comma'

    def test_real_02_expression_with_parens(self) -> None:
        """REAL-02-expression-with-parens"""
        grammar = {
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
        # Unclosed paren
        ok, err, skip = parse(grammar, '(n+n', 'E')
        assert ok, 'should insert missing close paren'

    def test_real_03_statement_list(self) -> None:
        """REAL-03-statement-list"""
        grammar = {
            'Program': OneOrMore(Ref('Stmt')),
            'Stmt': Seq(Ref('Expr'), Str(';')),
            'Expr': First(
                Seq(Str('if'), Str('('), Ref('Expr'), Str(')'), Ref('Stmt')),
                Str('x'),
            ),
        }
        # Missing semicolon
        ok, err, skip = parse(grammar, 'x x;', 'Program')
        assert ok, 'should recover missing semicolon'

    def test_real_04_string_literal(self) -> None:
        """REAL-04-string-literal"""
        grammar = {
            'S': Seq(Str('"'), ZeroOrMore(CharRange('a', 'z')), Str('"')),
        }
        # Unclosed string
        ok, err, skip = parse(grammar, '"hello')
        assert ok, 'should insert missing quote'

    def test_real_05_nested_blocks(self) -> None:
        """REAL-05-nested-blocks"""
        grammar = {
            'Block': Seq(Str('{'), ZeroOrMore(Ref('Stmt')), Str('}')),
            'Stmt': First(
                Ref('Block'),
                Seq(Str('x'), Str(';'))
            ),
        }
        # Deeply nested with error
        ok, err, skip = parse(grammar, '{x;{x;Xx;}}', 'Block')
        assert ok, 'nested blocks should recover'


class TestEmergentInteractionTests:
    """Emergent Interaction Tests"""

    def test_emerg_01_lr_with_bounded_rep_recovery(self) -> None:
        """EMERG-01-lr-with-bounded-rep-recovery"""
        # LR rule containing bounded repetition during recovery
        # FIX #9: Bound propagation now reaches nested Repetitions through context
        grammar = {
            'S': Seq(Ref('E'), Str('end')),
            'E': First(
                Seq(Ref('E'), Str('+'), OneOrMore(Str('n'))),
                Str('n')
            ),
        }
        # Error inside the repetition during LR expansion
        ok, err, skip = parse(grammar, 'n+nXn+nnend')
        assert ok, 'LR with bounded rep should work'

    def test_emerg_02_probe_triggers_lr(self) -> None:
        """EMERG-02-probe-triggers-lr"""
        # A probe() call that triggers left recursion
        grammar = {
            'S': Seq(ZeroOrMore(Str('a')), Ref('E')),
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
        }
        # ZeroOrMore probes E to check bounds, E is LR
        ok, err, skip = parse(grammar, 'aaXn+n')
        assert ok, 'probe triggering LR should work'

    def test_emerg_03_recovery_resets_lr_expansion(self) -> None:
        """EMERG-03-recovery-resets-lr-expansion"""
        # After recovery, does LR expansion restart correctly?
        grammar = {
            'S': Seq(Ref('E'), Str(';'), Ref('E')),
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
        }
        # First E has error, second E should expand fresh
        ok, err, skip = parse(grammar, 'n+Xn;n+n+n')
        assert ok, 'second LR should expand independently'
        assert err == 1, 'only first E has error'

    def test_emerg_04_incomplete_propagation_through_lr(self) -> None:
        """EMERG-04-incomplete-propagation-through-lr"""
        # Incomplete flag must propagate through LR expansion
        grammar = {
            'E': First(
                Seq(Ref('E'), Str('+'), Ref('T')),
                Ref('T')
            ),
            'T': Seq(Str('n'), ZeroOrMore(Str('x'))),
        }
        # T has ZeroOrMore that should mark incomplete
        ok, err, skip = parse(grammar, 'nxx+nxQx', 'E')
        assert ok, 'incomplete should propagate through LR'

    def test_emerg_05_cache_version_after_lr_recovery(self) -> None:
        """EMERG-05-cache-version-after-lr-recovery"""
        # After LR expansion with recovery, is the cache version correct?
        grammar = {
            'S': Seq(Ref('E'), Str(';'), Ref('E')),
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
        }
        # Both E's expand, with error in first
        # Version tracking must be correct for second E
        ok, err, skip = parse(grammar, 'n+Xn+n;n+n')
        assert ok, 'version should be correct after LR recovery'
