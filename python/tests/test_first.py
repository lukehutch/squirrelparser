"""
SECTION 8: FIRST (ORDERED CHOICE) (15 tests)
"""

from squirrelparser import Str, Seq, First, OneOrMore
from .test_utils import parse


def test_fr01_match_1st() -> None:
    ok, err, _ = parse({
        'S': First(Str('abc'), Str('ab'), Str('a'))
    }, 'abc')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_fr02_match_2nd() -> None:
    ok, err, _ = parse({
        'S': First(Str('xyz'), Str('abc'))
    }, 'abc')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_fr03_match_3rd() -> None:
    ok, err, _ = parse({
        'S': First(Str('x'), Str('y'), Str('z'))
    }, 'z')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_fr04_with_recovery() -> None:
    ok, err, skip = parse({
        'S': First(
            Seq(OneOrMore(Str('x')), Str('!')),
            Str('fallback')
        )
    }, 'xZx!')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in skip, 'should skip Z'


def test_fr05_fallback() -> None:
    ok, err, _ = parse({
        'S': First(
            Seq(Str('a'), Str('b')),
            Str('x')
        )
    }, 'x')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_fr06_none_match() -> None:
    ok, _, _ = parse({
        'S': First(Str('a'), Str('b'), Str('c'))
    }, 'x')
    assert not ok, 'should fail'


def test_fr07_nested() -> None:
    ok, err, _ = parse({
        'S': First(
            First(Str('a'), Str('b')),
            Str('c')
        )
    }, 'b')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_fr08_deep_nested() -> None:
    ok, err, _ = parse({
        'S': First(
            First(
                First(Str('a'))
            )
        )
    }, 'a')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
