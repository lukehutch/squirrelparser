"""FIX #4 - MULTI-LEVEL BOUNDED RECOVERY Tests"""
from squirrelparser import Str, Seq, OneOrMore
from tests.test_utils import parse


def test_f4_l1_01_clean_2() -> None:
    """F4-L1-01-clean 2"""
    ok, err, _ = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, '(xx)(xx)')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f4_l1_02_clean_5() -> None:
    """F4-L1-02-clean 5"""
    ok, err, _ = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, '(xx)' * 5)
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f4_l1_03_err_first() -> None:
    """F4-L1-03-err first"""
    ok, err, skip = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, '(xZx)(xx)')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in ''.join(skip), 'should skip Z'


def test_f4_l1_04_err_mid() -> None:
    """F4-L1-04-err mid"""
    ok, err, skip = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, '(xx)(xZx)(xx)')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in ''.join(skip), 'should skip Z'


def test_f4_l1_05_err_last() -> None:
    """F4-L1-05-err last"""
    ok, err, skip = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, '(xx)(xZx)')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in ''.join(skip), 'should skip Z'


def test_f4_l1_06_err_all_3() -> None:
    """F4-L1-06-err all 3"""
    ok, err, skip = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, '(xAx)(xBx)(xCx)')
    assert ok, 'should succeed'
    assert err == 3, 'should have 3 errors'
    skip_str = ''.join(skip)
    assert 'A' in skip_str and 'B' in skip_str and 'C' in skip_str, 'should skip A, B, C'


def test_f4_l1_07_boundary() -> None:
    """F4-L1-07-boundary"""
    ok, err, skip = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, '(xx)Z(xx)')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in ''.join(skip), 'should skip Z'


def test_f4_l1_08_long_boundary() -> None:
    """F4-L1-08-long boundary"""
    ok, err, skip = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, '(xx)ZZZ(xx)')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'ZZZ' in ''.join(skip), 'should skip ZZZ'


def test_f4_l2_01_clean() -> None:
    """F4-L2-01-clean"""
    ok, err, _ = parse({
        'S': Seq(
            Str('{'),
            OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')'))),
            Str('}')
        )
    }, '{(xx)(xx)}')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f4_l2_02_err_inner() -> None:
    """F4-L2-02-err inner"""
    ok, err, skip = parse({
        'S': Seq(
            Str('{'),
            OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')'))),
            Str('}')
        )
    }, '{(xx)(xZx)}')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in ''.join(skip), 'should skip Z'


def test_f4_l2_03_err_outer() -> None:
    """F4-L2-03-err outer"""
    ok, err, skip = parse({
        'S': Seq(
            Str('{'),
            OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')'))),
            Str('}')
        )
    }, '{(xx)Z(xx)}')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in ''.join(skip), 'should skip Z'


def test_f4_l2_04_both_levels() -> None:
    """F4-L2-04-both levels"""
    ok, err, _ = parse({
        'S': Seq(
            Str('{'),
            OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')'))),
            Str('}')
        )
    }, '{(xAx)B(xCx)}')
    assert ok, 'should succeed'
    assert err == 3, 'should have 3 errors'


def test_f4_l3_01_clean() -> None:
    """F4-L3-01-clean"""
    ok, err, _ = parse({
        'S': Seq(
            Str('['),
            Seq(
                Str('{'),
                OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')'))),
                Str('}')
            ),
            Str(']')
        )
    }, '[{(xx)(xx)}]')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f4_l3_02_err_deepest() -> None:
    """F4-L3-02-err deepest"""
    ok, err, skip = parse({
        'S': Seq(
            Str('['),
            Seq(
                Str('{'),
                OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')'))),
                Str('}')
            ),
            Str(']')
        )
    }, '[{(xx)(xZx)}]')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in ''.join(skip), 'should skip Z'


def test_f4_n1_10_groups() -> None:
    """F4-N1-10 groups"""
    ok, err, _ = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, '(xx)' * 10)
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f4_n2_10_groups_5_err() -> None:
    """F4-N2-10 groups 5 err"""
    input_str = ''.join('(xZx)' if i % 2 == 0 else '(xx)' for i in range(10))
    ok, err, _ = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, input_str)
    assert ok, 'should succeed'
    assert err == 5, 'should have 5 errors'


def test_f4_n3_20_groups() -> None:
    """F4-N3-20 groups"""
    ok, err, _ = parse({
        'S': OneOrMore(Seq(Str('('), OneOrMore(Str('x')), Str(')')))
    }, '(xx)' * 20)
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
