"""Repetition Edge Case Tests"""
from squirrelparser import Str, Seq, First, OneOrMore, ZeroOrMore
from tests.test_utils import parse


class TestRepetitionEdgeCaseTests:
    """Repetition Edge Case Tests"""

    def test_rep_01_zeoormore_empty_match(self) -> None:
        """REP-01-zeoormore-empty-match"""
        # ZeroOrMore can match zero times
        ok, err, _ = parse({
            'S': Seq(ZeroOrMore(Str('x')), Str('y'))
        }, 'y')
        assert ok, 'should succeed (ZeroOrMore matches 0)'
        assert err == 0, 'should have 0 errors'

    def test_rep_02_oneormore_vs_zeoormore_at_eof(self) -> None:
        """REP-02-oneormore-vs-zeoormore-at-eof"""
        # OneOrMore requires at least one match, ZeroOrMore doesn't
        # With spanning invariant, OneOrMore on empty input returns SyntaxError
        om_ok, _, _ = parse({'S': OneOrMore(Str('x'))}, '')
        assert not om_ok, 'OneOrMore should fail on empty input (total failure returns SyntaxError)'

        zm_ok, _, _ = parse({'S': ZeroOrMore(Str('x'))}, '')
        assert zm_ok, 'ZeroOrMore should succeed on empty input'

    def test_rep_03_nested_repetition(self) -> None:
        """REP-03-nested-repetition"""
        # OneOrMore(OneOrMore(x)) - nested repetitions
        ok, err, _ = parse({'S': OneOrMore(OneOrMore(Str('x')))}, 'xxxXxxXxxx')
        assert ok, 'should succeed'
        assert err == 2, 'should have 2 errors (two X gaps)'
        # Outer: matches 3 times (group1, skip X, group2, skip X, group3)
        # Each group is inner OneOrMore matching x's

    def test_rep_04_repetition_with_recovery_hits_bound(self) -> None:
        """REP-04-repetition-with-recovery-hits-bound"""
        # Repetition with recovery, encounters bound
        ok, err, skip = parse({
            'S': Seq(OneOrMore(Str('x')), Str('end'))
        }, 'xXxXxend')
        assert ok, 'should succeed'
        assert err == 2, 'should have 2 errors'
        assert len(skip) == 2, 'should skip 2 Xs'
        # Repetition stops before 'end' (bound)

    def test_rep_05_repetition_recovery_vs_probe(self) -> None:
        """REP-05-repetition-recovery-vs-probe"""
        # ZeroOrMore must probe ahead to avoid consuming boundary
        ok, err, _ = parse({
            'S': Seq(ZeroOrMore(Str('x')), Str('y'))
        }, 'xxxy')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors'
        # ZeroOrMore should match all x's, stop before 'y'

    def test_rep_06_alternating_match_skip_pattern(self) -> None:
        """REP-06-alternating-match-skip-pattern"""
        # Pattern: match, skip, match, skip, ...
        ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, 'abXabXabXab')
        assert ok, 'should succeed'
        assert err == 3, 'should have 3 errors (3 Xs)'

    def test_rep_07_repetition_of_complex_structure(self) -> None:
        """REP-07-repetition-of-complex-structure"""
        # OneOrMore(Seq([...])) - repetition of sequences
        ok, err, _ = parse({
            'S': OneOrMore(Seq(Str('a'), Str('b')))
        }, 'ababab')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors'
        # Matches 3 times: (a,b), (a,b), (a,b)

    def test_rep_08_repetition_stops_on_non_match(self) -> None:
        """REP-08-repetition-stops-on-non-match"""
        # Repetition stops when element no longer matches
        ok, err, _ = parse({
            'S': Seq(OneOrMore(Str('x')), Str('y'))
        }, 'xxxy')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors'
        # OneOrMore matches 3 x's, stops, then 'y' matches

    def test_rep_09_repetition_with_first_alternative(self) -> None:
        """REP-09-repetition-with-first-alternative"""
        # OneOrMore(First([...])) - repetition of alternatives
        ok, err, _ = parse({
            'S': OneOrMore(First(Str('a'), Str('b')))
        }, 'aabba')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors'
        # Matches 5 times: a, a, b, b, a

    def test_rep_10_zeoormore_with_recovery_inside(self) -> None:
        """REP-10-zeoormore-with-recovery-inside"""
        # ZeroOrMore element needs recovery
        ok, err, skip = parse({
            'S': ZeroOrMore(Seq(Str('a'), Str('b')))
        }, 'abXaYb')
        assert ok, 'should succeed'
        assert err == 2, 'should have 2 errors'
        # First iteration: a, b (clean)
        # Second iteration: tries at position 2, sees "Xa", Seq needs recovery

    def test_rep_11_greedy_vs_non_greedy(self) -> None:
        """REP-11-greedy-vs-non-greedy"""
        # Repetitions are greedy - match as many as possible
        ok, err, _ = parse({
            'S': Seq(ZeroOrMore(Str('x')), Str('y'), Str('z'))
        }, 'xxxxxyz')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors'
        # ZeroOrMore is greedy, matches all x's, then y and z

    def test_rep_12_repetition_at_eof_with_deletion(self) -> None:
        """REP-12-repetition-at-eof-with-deletion"""
        # Repetition at EOF can have grammar deletion (completion)
        ok, _, _ = parse({
            'S': Seq(Str('a'), OneOrMore(Str('b')))
        }, 'a')
        assert ok, 'should succeed (delete b+ at EOF)'
        # At EOF, can delete the OneOrMore requirement

    def test_rep_13_very_long_repetition(self) -> None:
        """REP-13-very-long-repetition"""
        # Performance test: many iterations
        input_str = 'x' * 1000
        ok, err, _ = parse({'S': OneOrMore(Str('x'))}, input_str)
        assert ok, 'should succeed (1000 iterations)'
        assert err == 0, 'should have 0 errors'

    def test_rep_14_repetition_with_many_errors(self) -> None:
        """REP-14-repetition-with-many-errors"""
        # Many errors within repetition
        input_str = ''.join('Xx' for _ in range(100))
        ok, err, _ = parse({'S': OneOrMore(Str('x'))}, input_str)
        assert ok, 'should succeed'
        assert err == 100, 'should have 100 errors'

    def test_rep_15_nested_zeoormore(self) -> None:
        """REP-15-nested-zeoormore"""
        # ZeroOrMore(ZeroOrMore(...)) - both can match zero
        ok, err, _ = parse({
            'S': Seq(ZeroOrMore(ZeroOrMore(Str('x'))), Str('y'))
        }, 'y')
        assert ok, 'should succeed (both match 0)'
        assert err == 0, 'should have 0 errors'
