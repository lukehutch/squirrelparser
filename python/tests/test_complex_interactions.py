"""Complex Interactions Tests - complex combinations of features"""
from squirrelparser import Str, Seq, First, OneOrMore, ZeroOrMore, Optional, NotFollowedBy, FollowedBy, Ref, Clause
from tests.test_utils import parse


class TestComplexInteractionsTests:
    """Complex Interactions Tests"""

    def test_complex_01_lr_bound_recovery_all_together(self) -> None:
        """COMPLEX-01-lr-bound-recovery-all-together"""
        ok, err, skip = parse({
            'S': Seq(Ref('E'), Str('end')),
            'E': First(
                Seq(Ref('E'), Str('+'), OneOrMore(Str('n'))),
                Str('n')
            )
        }, 'n+nXn+nnend')
        assert ok, 'should succeed (FIX #9 bound propagation)'
        assert err > 0, 'should have at least 1 error'
        assert 'X' in ''.join(skip), 'should skip X'

    def test_complex_02_nested_first_with_different_recovery_costs(self) -> None:
        """COMPLEX-02-nested-first-with-different-recovery-costs"""
        ok, err, _ = parse({
            'S': First(
                Seq(
                    First(Str('x'), Str('y')),
                    Str('z')
                ),
                Str('a')
            )
        }, 'xXz')
        assert ok, 'should succeed'
        assert err == 1, 'should choose first alternative with recovery'

    def test_complex_03_recovery_version_overflow_verified(self) -> None:
        """COMPLEX-03-recovery-version-overflow-verified"""
        input_str = 'ab' + ''.join('Xab' for _ in range(50))
        ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, input_str)
        assert ok, 'should succeed (version counter handles 50+ recoveries)'
        assert err == 50, 'should count all 50 errors'

    def test_complex_04_probe_during_recovery(self) -> None:
        """COMPLEX-04-probe-during-recovery"""
        ok, err, skip = parse({
            'S': Seq(
                ZeroOrMore(Str('x')),
                First(Str('y'), Str('z'))
            )
        }, 'xXxz')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error'
        assert 'X' in ''.join(skip), 'should skip X'

    def test_complex_05_multiple_refs_same_rule_with_recovery(self) -> None:
        """COMPLEX-05-multiple-refs-same-rule-with-recovery"""
        ok, err, skip = parse({
            'S': Seq(Ref('A'), Str('+'), Ref('A')),
            'A': Str('n')
        }, 'nX+n')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error'

    def test_complex_06_deeply_nested_lr(self) -> None:
        """COMPLEX-06-deeply-nested-lr"""
        ok, err, _ = parse({
            'A': First(
                Seq(Ref('A'), Str('a'), Ref('B')),
                Ref('B')
            ),
            'B': First(
                Seq(Ref('B'), Str('b'), Str('x')),
                Str('x')
            )
        }, 'xbXxaXxbx', 'A')
        assert ok, 'should succeed'
        assert err == 2, 'should have 2 errors (Xs at both A and B levels)'

    def test_complex_07_recovery_with_lookahead(self) -> None:
        """COMPLEX-07-recovery-with-lookahead"""
        # Recovery near lookahead assertions
        ok, err, skip = parse({
            'S': Seq(Str('a'), FollowedBy(Str('b')), Str('b'), Str('c'))
        }, 'aXbc')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error'
        assert 'X' in ''.join(skip), 'should skip X'
        # After skipping X, FollowedBy(b) checks 'b' without consuming

    def test_complex_08_recovery_in_negative_lookahead(self) -> None:
        """COMPLEX-08-recovery-in-negative-lookahead"""
        # NotFollowedBy with recovery context
        ok, err, _ = parse({
            'S': Seq(Str('a'), NotFollowedBy(Str('x')), Str('b'))
        }, 'ab')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors'
        # NotFollowedBy('x') succeeds (next is 'b', not 'x')

    def test_complex_09_alternating_lr_and_repetition(self) -> None:
        """COMPLEX-09-alternating-lr-and-repetition"""
        # Grammar with both LR and repetitions at same level
        ok, err, _ = parse({
            'S': Seq(Ref('E'), Str(';'), OneOrMore(Str('x'))),
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            )
        }, 'n+n;xxx')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors'
        # E is left-recursive, then ';', then repetition

    def test_complex_10_recovery_spanning_multiple_clauses(self) -> None:
        """COMPLEX-10-recovery-spanning-multiple-clauses"""
        # Single error region that spans where multiple clauses would try to match
        ok, err, skip = parse({
            'S': Seq(Str('a'), Str('b'), Str('c'), Str('d'))
        }, 'aXYZbcd')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error (entire XYZ region)'
        assert 'XYZ' in ''.join(skip), 'should skip XYZ as single region'

    def test_complex_11_ref_through_multiple_indirections(self) -> None:
        """COMPLEX-11-ref-through-multiple-indirections"""
        # A -> B -> C -> D, all Refs
        ok, err, _ = parse(
            {'A': Ref('B'), 'B': Ref('C'), 'C': Ref('D'), 'D': Str('x')},
            'x',
            'A')
        assert ok, 'should succeed (multiple Ref indirections)'
        assert err == 0, 'should have 0 errors'

    def test_complex_12_circular_refs_with_recovery(self) -> None:
        """COMPLEX-12-circular-refs-with-recovery"""
        # Mutual recursion with simple clean input
        ok, err, skip = parse({
            'S': Seq(Ref('A'), Str('end')),
            'A': First(
                Seq(Str('a'), Ref('B')),
                Str('a')
            ),
            'B': First(
                Seq(Str('b'), Ref('A')),
                Str('b')
            )
        }, 'ababend', 'S')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors (clean parse)'
        # Mutual recursion: A -> B -> A -> B (abab)

    def test_complex_13_all_clause_types_in_one_grammar(self) -> None:
        """COMPLEX-13-all-clause-types-in-one-grammar"""
        # Every clause type in one complex grammar
        ok, err, _ = parse({
            'S': Seq(
                Ref('A'),
                Optional(Str('opt')),
                ZeroOrMore(Str('z')),
                First(Str('f1'), Str('f2')),
                FollowedBy(Str('end')),
                Str('end')
            ),
            'A': First(
                Seq(Ref('A'), Str('+'), Str('a')),
                Str('a')
            )
        }, 'a+aoptzzzf1end', 'S')
        assert ok, 'should succeed (all clause types work together)'
        assert err == 0, 'should have 0 errors'

    def test_complex_14_recovery_at_every_level_of_deep_nesting(self) -> None:
        """COMPLEX-14-recovery-at-every-level-of-deep-nesting"""
        # Error at each level of deep nesting, all recover
        ok, err, _ = parse({
            'S': Seq(
                Seq(
                    Str('a'),
                    Seq(
                        Str('b'),
                        Seq(Str('c'), Str('d'))
                    )
                )
            )
        }, 'aXbYcZd')
        assert ok, 'should succeed'
        assert err == 3, 'should have 3 errors'
        # Error at each nesting level

    def test_complex_15_performance_large_grammar(self) -> None:
        """COMPLEX-15-performance-large-grammar"""
        # Large grammar with many rules
        rules: dict[str, Clause] = {}
        for i in range(50):
            rules[f'Rule{i}'] = Str(f'opt_{str(i).zfill(3)}')
        rules['S'] = First(*[Ref(f'Rule{i}') for i in range(50)])

        ok, _, _ = parse(rules, 'opt_025', 'S')
        assert ok, 'should succeed (large grammar with 50 rules)'
