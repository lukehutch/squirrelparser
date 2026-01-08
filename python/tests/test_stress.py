"""
SECTION 11: STRESS TESTS (20 tests)
"""

from squirrelparser import Str, Seq, First, OneOrMore, Optional, Ref
from .test_utils import parse


def test_st01_1000_clean() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, 'ab' * 500)
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_st02_1000_err() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, 'ab' * 250 + 'XX' + 'ab' * 249)
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'


def test_st03_100_groups() -> None:
    ok, err, _ = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, '(xx)' * 100)
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_st04_100_groups_err() -> None:
    input_str = ''.join('(xZx)' if i % 10 == 5 else '(xx)' for i in range(100))
    ok, err, _ = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, input_str)
    assert ok, 'should succeed'
    assert err == 10, 'should have 10 errors'


def test_st05_deep_nesting() -> None:
    ok, err, _ = parse({
        'S': Seq(Str('('), Ref('A'), Str(')')),
        'A': First(
            Seq(Str('('), Ref('A'), Str(')')),
            Str('x')
        )
    }, '(' * 15 + 'x' + ')' * 15)
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_st06_50_alts() -> None:
    alts = [Str(f'opt{i}') for i in range(50)] + [Str('match')]
    ok, err, _ = parse({'S': First(*alts)}, 'match')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_st07_500_chars() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('x'))}, 'x' * 500)
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_st08_500plus5err() -> None:
    input_str = 'x' * 100
    for _ in range(5):
        input_str += 'Z' + 'x' * 99
    ok, err, _ = parse({'S': OneOrMore(Str('x'))}, input_str)
    assert ok, 'should succeed'
    assert err == 5, 'should have 5 errors'


def test_st09_100_seq() -> None:
    clauses = [Str('x')] * 100
    ok, err, _ = parse({'S': Seq(*clauses)}, 'x' * 100)
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_st10_50_optional() -> None:
    clauses = [Optional(Str('x'))] * 50 + [Str('!')]
    ok, err, _ = parse({'S': Seq(*clauses)}, 'x' * 25 + '!')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_st11_nested_rep() -> None:
    ok, err, _ = parse({'S': OneOrMore(OneOrMore(Str('x')))}, 'x' * 200)
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_st12_long_err_span() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, 'ab' + 'X' * 200 + 'ab')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'


def test_st13_many_short_err() -> None:
    input_str = 'abX' * 30 + 'ab'
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, input_str)
    assert ok, 'should succeed'
    assert err == 30, 'should have 30 errors'


def test_st14_2000_clean() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('x'))}, 'x' * 2000)
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_st15_2000_err() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('x'))}, 'x' * 1000 + 'ZZ' + 'x' * 998)
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'


def test_st16_200_groups() -> None:
    ok, err, _ = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, '(xx)' * 200)
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_st17_200_groups_20err() -> None:
    input_str = ''.join('(xZx)' if i % 10 == 0 else '(xx)' for i in range(200))
    ok, err, _ = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, input_str)
    assert ok, 'should succeed'
    assert err == 20, 'should have 20 errors'


def test_st18_50_errors() -> None:
    input_str = 'abZ' * 50 + 'ab'
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, input_str)
    assert ok, 'should succeed'
    assert err == 50, 'should have 50 errors'


def test_st19_deep_l5() -> None:
    ok, err, skip = parse({
        'S': Seq(
            Str('1'),
            Seq(
                Str('2'),
                Seq(
                    Str('3'),
                    Seq(
                        Str('4'),
                        Seq(Str('5'), OneOrMore(Str('x')), Str('5')),
                        Str('4')
                    ),
                    Str('3')
                ),
                Str('2')
            ),
            Str('1')
        )
    }, '12345xZx54321')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in skip, 'should skip Z'


def test_st20_very_deep_nest() -> None:
    ok, err, _ = parse({
        'S': Seq(Str('('), Ref('A'), Str(')')),
        'A': First(
            Seq(Str('('), Ref('A'), Str(')')),
            Str('x')
        )
    }, '(' * 20 + 'x' + ')' * 20)
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
