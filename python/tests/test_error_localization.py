"""Error Localization Tests - verify errors don't cascade"""
from squirrelparser import Str, Seq, First, OneOrMore, Ref
from tests.test_utils import parse


class TestErrorLocalizationNonCascadingTests:
    """Error Localization (Non-Cascading) Tests"""

    def test_cascade_01_error_in_first_element_doesnt_affect_second(self) -> None:
        """CASCADE-01-error-in-first-element-doesnt-affect-second"""
        ok, err, skip = parse({
            'S': Seq(Str('a'), Str('b'), Str('c'))
        }, 'aXbc')
        assert ok, 'should succeed'
        assert err == 1, 'should have exactly 1 error (at position 1)'
        assert 'X' in ''.join(skip), 'should skip X'

    def test_cascade_02_error_in_nested_structure(self) -> None:
        """CASCADE-02-error-in-nested-structure"""
        ok, err, skip = parse({
            'S': Seq(
                Seq(Str('a'), Str('b')),
                Str('c')
            )
        }, 'aXbc')
        assert ok, 'should succeed'
        assert err == 1, 'should have exactly 1 error'
        assert 'X' in ''.join(skip), 'should skip X'

    def test_cascade_03_lr_error_doesnt_cascade_to_next_expansion(self) -> None:
        """CASCADE-03-lr-error-doesnt-cascade-to-next-expansion"""
        ok, err, skip = parse({
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            )
        }, 'n+Xn+n', 'E')
        assert ok, 'should succeed'
        assert err == 1, 'should have exactly 1 error'
        assert 'X' in ''.join(skip), 'should skip X'

    def test_cascade_04_multiple_independent_errors(self) -> None:
        """CASCADE-04-multiple-independent-errors"""
        ok, err, skip = parse({
            'S': Seq(
                Seq(Str('a'), Str('b')),
                Seq(Str('c'), Str('d')),
                Seq(Str('e'), Str('f'))
            )
        }, 'aXbcYdeZf')
        assert ok, 'should succeed'
        assert err == 3, 'should have 3 independent errors'
        skip_str = ''.join(skip)
        assert 'X' in skip_str, 'should skip X'
        assert 'Y' in skip_str, 'should skip Y'
        assert 'Z' in skip_str, 'should skip Z'

    def test_cascade_05_error_before_repetition(self) -> None:
        """CASCADE-05-error-before-repetition"""
        ok, err, skip = parse({
            'S': Seq(Str('a'), OneOrMore(Str('b')))
        }, 'aXbbb')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error'
        assert 'X' in ''.join(skip), 'should skip X'

    def test_cascade_06_error_after_repetition(self) -> None:
        """CASCADE-06-error-after-repetition"""
        ok, err, skip = parse({
            'S': Seq(OneOrMore(Str('a')), Str('b'))
        }, 'aaaXb')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error'
        assert 'X' in ''.join(skip), 'should skip X'

    def test_cascade_07_error_in_first_alternative_doesnt_poison_second(self) -> None:
        """CASCADE-07-error-in-first-alternative-doesnt-poison-second"""
        # First alternative has error, second alternative clean
        ok, err, _ = parse({
            'S': First(
                Seq(Str('a'), Str('b')),
                Str('c')
            )
        }, 'c')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors (second alternative clean)'
        # First tries and fails, second succeeds cleanly - no cascade

    def test_cascade_08_recovery_version_increments_correctly(self) -> None:
        """CASCADE-08-recovery-version-increments-correctly"""
        # Each recovery increments version, ensuring proper cache invalidation
        ok, err, _ = parse({
            'S': Seq(
                Seq(Str('a'), Str('b')),
                Seq(Str('c'), Str('d'))
            )
        }, 'aXbcYd')
        assert ok, 'should succeed'
        assert err == 2, 'should have 2 errors'
        # Two recoveries, each increments version, no cache pollution

    def test_cascade_09_error_at_deeply_nested_level(self) -> None:
        """CASCADE-09-error-at-deeply-nested-level"""
        # Error very deep in nesting, doesn't affect outer levels
        ok, err, skip = parse({
            'S': Seq(
                Seq(
                    Seq(
                        Seq(Str('a'), Str('b')),
                        Str('c')
                    ),
                    Str('d')
                ),
                Str('e')
            )
        }, 'aXbcde')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error at deepest level'
        assert 'X' in ''.join(skip), 'should skip X'
        # Error localized despite 4 levels of nesting

    def test_cascade_10_error_recovery_doesnt_leave_parser_in_bad_state(self) -> None:
        """CASCADE-10-error-recovery-doesnt-leave-parser-in-bad-state"""
        # After recovery, parser continues with clean state
        ok, err, _ = parse({
            'S': Seq(
                Seq(Str('a'), Str('b')),
                Str('c'),  # Expects 'c' at position 2
                Seq(Str('d'), Str('e'))
            )
        }, 'abXcde')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error'
        # After skipping X at position 2, matches 'c' at position 3, then 'de'
