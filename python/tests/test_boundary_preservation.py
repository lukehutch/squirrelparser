"""
BOUNDARY PRESERVATION TESTS

These tests verify that recovery doesn't consume content meant for
subsequent grammar elements (preserve structural boundaries).
"""

from squirrelparser import Str, Seq, First, OneOrMore, ZeroOrMore
from .test_utils import parse


def test_bnd_01_dont_consume_next_terminal() -> None:
    # Recovery should skip 'X' but not consume 'b' (needed by next element)
    ok, err, skip = parse({
        'S': Seq(Str('a'), Str('b'))
    }, 'aXb')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'X' in skip, 'should skip X'
    # Verify 'b' was matched by second element, not consumed during recovery


def test_bnd_02_dont_partially_consume_next_terminal() -> None:
    # Multi-char terminals are atomic - recovery can't consume part of 'cd'
    ok, err, skip = parse({
        'S': Seq(Str('ab'), Str('cd'))
    }, 'abXcd')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'X' in skip, 'should skip X'
    # 'cd' should be matched atomically by second element


def test_bnd_03_recovery_in_first_doesnt_poison_alternatives() -> None:
    # First alternative fails cleanly, second succeeds
    ok, err, _ = parse({
        'S': First(
            Seq(Str('a'), Str('b')),
            Seq(Str('c'), Str('d'))
        )
    }, 'cd')
    assert ok, 'should succeed (second alternative)'
    assert err == 0, 'should have 0 errors (clean match)'


def test_bnd_04_first_alternative_with_recovery_vs_second_clean() -> None:
    # First alternative needs recovery, second is clean
    # Should prefer first (longer match, see FIX #2)
    ok, err, _ = parse({
        'S': First(
            Seq(Str('a'), Str('b'), Str('c')),
            Str('a')
        )
    }, 'aXbc')
    assert ok, 'should succeed'
    # FIX #2: Prefer longer matches over fewer errors
    assert err == 1, 'should choose first alternative (longer despite error)'


def test_bnd_05_boundary_with_nested_repetition() -> None:
    # Repetition with bound should stop at delimiter
    ok, err, _ = parse({
        'S': Seq(OneOrMore(Str('x')), Str(';'), OneOrMore(Str('y')))
    }, 'xxx;yyy')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
    # x+ stops at ';', y+ stops at EOF


def test_bnd_06_boundary_with_recovery_before_delimiter() -> None:
    # Recovery happens, but delimiter is preserved
    ok, err, skip = parse({
        'S': Seq(OneOrMore(Str('x')), Str(';'), OneOrMore(Str('y')))
    }, 'xxXx;yyy')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'X' in skip, 'should skip X'
    # ';' should not be consumed during recovery of x+


def test_bnd_07_probe_respects_boundaries() -> None:
    # ZeroOrMore probes ahead to find boundary
    ok, err, _ = parse({
        'S': Seq(
            ZeroOrMore(Str('x')),
            First(Str('y'), Str('z'))
        )
    }, 'xxxz')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
    # ZeroOrMore should probe, find 'z' matches First, stop before it


def test_bnd_08_complex_boundary_nesting() -> None:
    # Nested sequences with multiple boundaries
    ok, err, _ = parse({
        'S': Seq(
            Seq(OneOrMore(Str('a')), Str('+')),
            Seq(OneOrMore(Str('b')), Str('='))
        )
    }, 'aaa+bbb=')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
    # Each repetition stops at its delimiter


def test_bnd_09_boundary_with_eof() -> None:
    # No explicit boundary - should consume until EOF
    ok, err, _ = parse({'S': OneOrMore(Str('x'))}, 'xxxxx')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
    # Consumes all x's (no boundary to stop at)


def test_bnd_10_recovery_near_boundary() -> None:
    # Error just before boundary - should not cross boundary
    ok, err, skip = parse({
        'S': Seq(OneOrMore(Str('x')), Str(';'))
    }, 'xxX;')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'X' in skip, 'should skip X'
    # ';' should remain for second element
