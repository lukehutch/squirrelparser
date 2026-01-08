"""First Alternative Selection Tests - FIX #2 Verification"""
from squirrelparser import Str, Seq, First, OneOrMore, Ref
from tests.test_utils import parse


class TestFirstAlternativeSelectionTests:
    """First Alternative Selection Tests"""

    def test_first_01_all_alternatives_fail_cleanly(self) -> None:
        """FIRST-01-all-alternatives-fail-cleanly"""
        ok, _, _ = parse({
            'S': First(Str('a'), Str('b'), Str('c'))
        }, 'x')
        assert not ok, 'should fail (no alternative matches)'

    def test_first_02_first_needs_recovery_second_clean(self) -> None:
        """FIRST-02-first-needs-recovery-second-clean"""
        ok, err, _ = parse({
            'S': First(
                Seq(Str('a'), Str('b')),
                Str('c')
            )
        }, 'aXb')
        assert ok, 'should succeed'
        assert err == 1, 'first alternative chosen (longer despite error)'

    def test_first_03_all_alternatives_need_recovery(self) -> None:
        """FIRST-03-all-alternatives-need-recovery"""
        ok, err, _ = parse({
            'S': First(
                Seq(Str('a'), Str('b'), Str('c')),  # aXbc: len=4, 1 error
                Seq(Str('a'), Str('y'), Str('z'))  # would need different recovery
            )
        }, 'aXbc')
        assert ok, 'should succeed'
        assert err == 1, 'should choose first alternative (matches with recovery)'

    def test_first_04_longer_with_error_vs_shorter_clean(self) -> None:
        """FIRST-04-longer-with-error-vs-shorter-clean"""
        ok, err, _ = parse({
            'S': First(
                Seq(Str('a'), Str('b'), Str('c')),  # len=3, 1 error
                Str('a')  # len=1, 0 errors
            )
        }, 'aXbc')
        assert ok, 'should succeed'
        assert err == 1, 'should choose first (longer despite error)'

    def test_first_05_same_length_fewer_errors_wins(self) -> None:
        """FIRST-05-same-length-fewer-errors-wins"""
        ok, err, _ = parse({
            'S': First(
                Seq(
                    Str('a'),
                    Str('b'),
                    Str('c'),
                    Str('d')
                ),  # aXYcd: len=5, 2 errors
                Seq(Str('a'), Str('b'), Str('c'))  # aXbc: len=4, 1 error
            )
        }, 'aXbc')
        assert ok, 'should succeed'
        assert err == 1, 'should choose second (fewer errors)'

    def test_first_06_multiple_clean_alternatives(self) -> None:
        """FIRST-06-multiple-clean-alternatives"""
        ok, err, _ = parse({
            'S': First(
                Str('abc'),
                Str('abc'),  # Same as first
                Str('ab')
            )
        }, 'abc')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors (clean match)'

    def test_first_07_prefer_longer_clean_over_shorter_clean(self) -> None:
        """FIRST-07-prefer-longer-clean-over-shorter-clean"""
        ok, err, _ = parse({
            'S': First(Str('abc'), Str('ab'))
        }, 'abc')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors'

    def test_first_08_fallback_after_all_longer_fail(self) -> None:
        """FIRST-08-fallback-after-all-longer-fail"""
        # Longer alternatives fail, shorter succeeds
        ok, err, _ = parse({
            'S': First(
                Seq(Str('x'), Str('y'), Str('z')),
                Str('a')
            )
        }, 'a')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors (clean second alternative)'

    def test_first_09_left_recursive_alternative(self) -> None:
        """FIRST-09-left-recursive-alternative"""
        # First contains left-recursive alternative
        ok, err, _ = parse({
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            )
        }, 'n+Xn', 'E')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error'
        # LR expansion with recovery

    def test_first_10_nested_first(self) -> None:
        """FIRST-10-nested-first"""
        # First containing another First
        ok, err, _ = parse({
            'S': First(
                First(Str('a'), Str('b')),
                Str('c')
            )
        }, 'b')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors'
        # Outer First tries first alternative (inner First), which matches 'b'

    def test_first_11_all_alternatives_incomplete(self) -> None:
        """FIRST-11-all-alternatives-incomplete"""
        # All alternatives incomplete (don't consume full input)
        # With spanning invariant, parser recovers from remaining input
        ok, err, skip = parse({
            'S': First(Str('a'), Str('b'))
        }, 'aXXX')
        assert ok, 'should succeed with recovery (First chooses a, XXX skipped)'
        assert err == 1, 'should have 1 error (XXX)'
        assert 'XXX' in skip, 'should skip XXX'

    def test_first_12_recovery_with_complex_alternatives(self) -> None:
        """FIRST-12-recovery-with-complex-alternatives"""
        # Complex alternatives with nested structures
        ok, err, _ = parse({
            'S': First(
                Seq(OneOrMore(Str('x')), Str('y')),
                Seq(OneOrMore(Str('a')), Str('b'))
            )
        }, 'xxxXy')
        assert ok, 'should succeed'
        assert err == 1, 'should choose first alternative'
