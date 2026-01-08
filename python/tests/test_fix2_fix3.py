"""FIX #2/#3 - CACHE INTEGRITY Tests"""
from squirrelparser import Str, Seq, OneOrMore, Ref
from tests.test_utils import parse


def test_f2_01_basic_probe() -> None:
    """F2-01-Basic probe"""
    ok, err, skip = parse({
        'S': Seq(Str('('), OneOrMore(Str('x')), Str(')'))
    }, '(xZZx)')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'ZZ' in ''.join(skip), 'should skip ZZ'


def test_f2_02_double_probe() -> None:
    """F2-02-Double probe"""
    ok, err, _ = parse({
        'S': Seq(
            Str('a'),
            OneOrMore(Str('x')),
            Str('b'),
            OneOrMore(Str('y')),
            Str('c')
        )
    }, 'axXxbyYyc')
    assert ok, 'should succeed'
    assert err == 2, 'should have 2 errors'


def test_f2_03_probe_same_clause() -> None:
    """F2-03-Probe same clause"""
    ok, err, skip = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, '(xZx)(xYx)')
    assert ok, 'should succeed'
    assert err == 2, 'should have 2 errors'
    skip_str = ''.join(skip)
    assert 'Z' in skip_str and 'Y' in skip_str, 'should skip Z and Y'


def test_f2_04_triple_group() -> None:
    """F2-04-Triple group"""
    ok, err, _ = parse({
        'S': OneOrMore(Seq(Str('['), OneOrMore(Str('x')), Str(']')))
    }, '[xAx][xBx][xCx]')
    assert ok, 'should succeed'
    assert err == 3, 'should have 3 errors'


def test_f2_05_five_groups() -> None:
    """F2-05-Five groups"""
    ok, err, _ = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, '(xAx)(xBx)(xCx)(xDx)(xEx)')
    assert ok, 'should succeed'
    assert err == 5, 'should have 5 errors'


def test_f2_06_alternating_clean_err() -> None:
    """F2-06-Alternating clean/err"""
    ok, err, _ = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, '(xx)(xZx)(xx)(xYx)(xx)')
    assert ok, 'should succeed'
    assert err == 2, 'should have 2 errors'


def test_f2_07_long_inner_error() -> None:
    """F2-07-Long inner error"""
    ok, err, _ = parse({
        'S': Seq(Str('('), OneOrMore(Str('x')), Str(')'))
    }, '(x' + 'Z' * 20 + 'x)')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'


def test_f2_08_nested_probe() -> None:
    """F2-08-Nested probe"""
    ok, err, skip = parse({
        'S': Seq(
            Str('{'),
            Seq(Str('('), OneOrMore(Str('x')), Str(')')),
            Str('}')
        )
    }, '{(xZx)}')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in ''.join(skip), 'should skip Z'


def test_f2_09_triple_nested() -> None:
    """F2-09-Triple nested"""
    ok, err, skip = parse({
        'S': Seq(
            Str('<'),
            Seq(
                Str('{'),
                Seq(Str('['), OneOrMore(Str('x')), Str(']')),
                Str('}')
            ),
            Str('>')
        )
    }, '<{[xZx]}>')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in ''.join(skip), 'should skip Z'


def test_f2_10_ref_probe() -> None:
    """F2-10-Ref probe"""
    ok, err, skip = parse({
        'S': Seq(Str('('), Ref('R'), Str(')')),
        'R': OneOrMore(Str('x'))
    }, '(xZx)')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in ''.join(skip), 'should skip Z'
