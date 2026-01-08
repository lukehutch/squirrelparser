"""FIX #5/#6 - OPTIONAL AND EOF Tests"""
from squirrelparser import Str, Seq, First, OneOrMore, Optional, Ref, Parser
from tests.test_utils import parse


# Mutual recursion grammar
mr = {
    'S': Ref('A'),
    'A': First(
        Seq(Str('a'), Ref('B')),
        Str('y')
    ),
    'B': First(
        Seq(Str('b'), Ref('A')),
        Str('x')
    ),
}


def test_f5_01_aby() -> None:
    """F5-01-aby"""
    ok, err, _ = parse(mr, 'aby')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f5_02_abzy() -> None:
    """F5-02-abZy"""
    ok, err, skip = parse(mr, 'abZy')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in ''.join(skip), 'should skip Z'


def test_f5_03_ababy() -> None:
    """F5-03-ababy"""
    ok, err, _ = parse(mr, 'ababy')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f5_04_ax() -> None:
    """F5-04-ax"""
    ok, err, _ = parse(mr, 'ax')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f5_05_y() -> None:
    """F5-05-y"""
    ok, err, _ = parse(mr, 'y')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f5_06_abx() -> None:
    """F5-06-abx"""
    # 'abx' is NOT in the language: after 'ab' we need A which requires 'a' or 'y', not 'x'
    # Grammar produces: y, ax, aby, abax, ababy, etc.
    # So this requires error recovery (skip 'b' and match 'ax', or skip 'bx' and fail)
    ok, err, _ = parse(mr, 'abx')
    assert ok, 'should succeed with recovery'
    assert err >= 1, 'should have at least 1 error'


def test_f5_06b_abax() -> None:
    """F5-06b-abax"""
    # 'abax' IS in the language: A → a B → a b A → a b a B → a b a x
    ok, err, _ = parse(mr, 'abax')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f5_07_ababx() -> None:
    """F5-07-ababx"""
    # 'ababx' is NOT in the language: after 'abab' we need A which requires 'a' or 'y', not 'x'
    # Grammar produces: y, ax, aby, abax, ababy, ababax, abababy, etc.
    # So this requires error recovery
    ok, err, _ = parse(mr, 'ababx')
    assert ok, 'should succeed with recovery'
    assert err >= 1, 'should have at least 1 error'


def test_f5_07b_ababax() -> None:
    """F5-07b-ababax"""
    # 'ababax' IS in the language: A → a B → a b A → a b a B → a b a b A → a b a b a B → a b a b a x
    ok, err, _ = parse(mr, 'ababax')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f6_01_optional_wrapper() -> None:
    """F6-01-Optional wrapper"""
    ok, err, skip = parse({
        'S': Optional(Seq(OneOrMore(Str('x')), Str('!')))
    }, 'xZx!')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in ''.join(skip), 'should skip Z'


def test_f6_02_optional_at_eof() -> None:
    """F6-02-Optional at EOF"""
    ok, err, _ = parse({'S': Optional(Str('x'))}, '')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f6_03_nested_optional() -> None:
    """F6-03-Nested optional"""
    ok, err, skip = parse({
        'S': Optional(Optional(Seq(OneOrMore(Str('x')), Str('!'))))
    }, 'xZx!')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in ''.join(skip), 'should skip Z'


def test_f6_04_optional_in_seq() -> None:
    """F6-04-Optional in Seq"""
    ok, err, skip = parse({
        'S': Seq(
            Optional(Seq(OneOrMore(Str('x')))),
            Str('!')
        )
    }, 'xZx!')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in ''.join(skip), 'should skip Z'


def test_f6_05_eof_del_ok() -> None:
    """F6-05-EOF del ok"""
    from tests.test_utils import count_deletions
    parser = Parser(
        rules={
            'S': Seq(Str('a'), Str('b'), Str('c'))
        },
        input_str='ab',
    )
    result, used_recovery = parser.parse('S')
    assert result is not None and not result.is_mismatch, 'should succeed with recovery'
    assert count_deletions(result) == 1, 'should have 1 deletion'
