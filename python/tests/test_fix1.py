"""
SECTION 2: FIX #1 - isComplete PROPAGATION (25 tests)
"""

from squirrelparser import Str, Seq, First, OneOrMore, ZeroOrMore, Optional
from .test_utils import parse


def test_f1_01_rep_seq_basic() -> None:
    ok, err, skip = parse({
        'S': Seq(OneOrMore(Str('ab')), Str('!'))
    }, 'abXXab!')
    assert ok, 'should succeed'
    assert err == 1, f'should have 1 error, got {err}'
    assert 'XX' in skip, 'should skip XX'


def test_f1_02_rep_optional() -> None:
    ok, err, skip = parse({
        'S': Seq(OneOrMore(Str('ab')), Optional(Str('!')))
    }, 'abXXab')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'XX' in skip, 'should skip XX'


def test_f1_03_rep_optional_match() -> None:
    ok, err, skip = parse({
        'S': Seq(OneOrMore(Str('ab')), Optional(Str('!')))
    }, 'abXXab!')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'XX' in skip, 'should skip XX'


def test_f1_04_first_wrapping() -> None:
    ok, err, _ = parse({
        'S': First(
            Seq(OneOrMore(Str('ab')), Str('!'))
        )
    }, 'abXXab!')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'


def test_f1_05_nested_seq_l1() -> None:
    ok, err, skip = parse({
        'S': Seq(
            Seq(OneOrMore(Str('x')))
        )
    }, 'xZx')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in skip, 'should skip Z'


def test_f1_06_nested_seq_l2() -> None:
    ok, err, skip = parse({
        'S': Seq(
            Seq(
                Seq(OneOrMore(Str('x')))
            )
        )
    }, 'xZx')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in skip, 'should skip Z'


def test_f1_07_nested_seq_l3() -> None:
    ok, err, skip = parse({
        'S': Seq(
            Seq(
                Seq(
                    Seq(OneOrMore(Str('x')))
                )
            )
        )
    }, 'xZx')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in skip, 'should skip Z'


def test_f1_08_optional_wrapping() -> None:
    ok, err, skip = parse({
        'S': Optional(Seq(OneOrMore(Str('x'))))
    }, 'xZx')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in skip, 'should skip Z'


def test_f1_09_zero_or_more_in_seq() -> None:
    ok, err, skip = parse({
        'S': Seq(ZeroOrMore(Str('ab')), Str('!'))
    }, 'abXXab!')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'XX' in skip, 'should skip XX'


def test_f1_10_multiple_reps() -> None:
    ok, err, _ = parse({
        'S': Seq(OneOrMore(Str('a')), OneOrMore(Str('b')))
    }, 'aXabYb')
    assert ok, 'should succeed'
    assert err == 2, 'should have 2 errors'


def test_f1_11_rep_rep_term() -> None:
    ok, err, _ = parse({
        'S': Seq(OneOrMore(Str('a')), OneOrMore(Str('b')), Str('!'))
    }, 'aXabYb!')
    assert ok, 'should succeed'
    assert err == 2, 'should have 2 errors'


def test_f1_12_long_error_span() -> None:
    ok, err, _ = parse({
        'S': Seq(OneOrMore(Str('x')), Str('!'))
    }, 'x' + 'Z' * 20 + 'x!')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'


def test_f1_13_multiple_long_errors() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, 'ab' + 'X' * 10 + 'ab' + 'Y' * 10 + 'ab')
    assert ok, 'should succeed'
    assert err == 2, 'should have 2 errors'


def test_f1_14_interspersed_errors() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, 'abXabYabZab')
    assert ok, 'should succeed'
    assert err == 3, 'should have 3 errors'


def test_f1_15_five_errors() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, 'abAabBabCabDabEab')
    assert ok, 'should succeed'
    assert err == 5, 'should have 5 errors'
