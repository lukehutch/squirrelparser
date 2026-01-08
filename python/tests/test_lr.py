"""
SECTION 9: LEFT RECURSION (10 tests)
"""

from squirrelparser import Str, CharRange, Seq, First, OneOrMore, Ref
from .test_utils import parse


# Define grammars
lr1 = {
    'S': First(
        Seq(Ref('S'), Str('+'), Ref('T')),
        Ref('T')
    ),
    'T': OneOrMore(CharRange('0', '9')),
}

expr = {
    'S': Ref('E'),
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
        CharRange('0', '9')
    ),
}


def test_lr01_simple() -> None:
    ok, err, _ = parse(lr1, '1+2+3')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_lr02_single() -> None:
    ok, err, _ = parse(lr1, '42')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_lr03_chain_5() -> None:
    ok, err, _ = parse(lr1, '+'.join(['1'] * 5))
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_lr04_chain_10() -> None:
    ok, err, _ = parse(lr1, '+'.join(['1'] * 10))
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_lr05_with_mult() -> None:
    ok, err, _ = parse(expr, '1+2*3')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_lr06_parens() -> None:
    ok, err, _ = parse(expr, '(1+2)*3')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_lr07_nested_parens() -> None:
    ok, err, _ = parse(expr, '((1+2))')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_lr08_direct() -> None:
    ok, err, _ = parse({
        'S': First(
            Seq(Ref('S'), Str('x')),
            Str('y')
        )
    }, 'yxxx')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_lr09_multi_digit() -> None:
    ok, err, _ = parse(lr1, '12+345+6789')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_lr10_complex_expr() -> None:
    ok, err, _ = parse(expr, '1+2*3+4*5')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
