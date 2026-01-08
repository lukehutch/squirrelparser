"""
SECTION 1: EMPTY AND BOUNDARY CONDITIONS (27 tests)
"""

from squirrelparser import (
    Parser, Str, CharRange, AnyChar, Seq, First,
    OneOrMore, ZeroOrMore, Optional, Ref
)
from .test_utils import parse, count_deletions


def test_e01_zero_or_more_empty() -> None:
    ok, err, _ = parse({'S': ZeroOrMore(Str('x'))}, '')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e02_one_or_more_empty() -> None:
    ok, _, _ = parse({'S': OneOrMore(Str('x'))}, '')
    assert not ok, 'should fail'


def test_e03_optional_empty() -> None:
    ok, err, _ = parse({'S': Optional(Str('x'))}, '')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e04_seq_empty_recovery() -> None:
    parser = Parser(
        rules={
            'S': Seq(Str('a'), Str('b'))
        },
        input_str='',
    )
    result, used_recovery = parser.parse('S')
    assert result is not None and not result.is_mismatch, 'should succeed with recovery'
    assert count_deletions(result) == 2, 'should have 2 deletions'


def test_e05_first_empty() -> None:
    ok, _, _ = parse({
        'S': First(Str('a'), Str('b'))
    }, '')
    assert not ok, 'should fail'


def test_e06_ref_empty() -> None:
    ok, _, _ = parse({'S': Ref('A'), 'A': Str('x')}, '')
    assert not ok, 'should fail'


def test_e07_single_char_match() -> None:
    ok, err, _ = parse({'S': Str('x')}, 'x')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e08_single_char_mismatch() -> None:
    ok, _, _ = parse({'S': Str('x')}, 'y')
    assert not ok, 'should fail'


def test_e09_zero_or_more_single() -> None:
    ok, err, _ = parse({'S': ZeroOrMore(Str('x'))}, 'x')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e10_one_or_more_single() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('x'))}, 'x')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e11_optional_match() -> None:
    ok, err, _ = parse({'S': Optional(Str('x'))}, 'x')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e12_two_chars_match() -> None:
    ok, err, _ = parse({'S': Str('xy')}, 'xy')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e13_two_chars_partial() -> None:
    ok, _, _ = parse({'S': Str('xy')}, 'x')
    assert not ok, 'should fail'


def test_e14_char_range_match() -> None:
    ok, err, _ = parse({'S': CharRange('a', 'z')}, 'm')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e15_char_range_boundary_low() -> None:
    ok, err, _ = parse({'S': CharRange('a', 'z')}, 'a')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e16_char_range_boundary_high() -> None:
    ok, err, _ = parse({'S': CharRange('a', 'z')}, 'z')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e17_char_range_fail_low() -> None:
    ok, _, _ = parse({'S': CharRange('b', 'y')}, 'a')
    assert not ok, 'should fail'


def test_e18_char_range_fail_high() -> None:
    ok, _, _ = parse({'S': CharRange('b', 'y')}, 'z')
    assert not ok, 'should fail'


def test_e19_any_char_match() -> None:
    ok, err, _ = parse({'S': AnyChar()}, 'x')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e20_any_char_empty() -> None:
    ok, _, _ = parse({'S': AnyChar()}, '')
    assert not ok, 'should fail'


def test_e21_seq_single() -> None:
    ok, err, _ = parse({
        'S': Seq(Str('x'))
    }, 'x')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e22_first_single() -> None:
    ok, err, _ = parse({
        'S': First(Str('x'))
    }, 'x')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e23_nested_empty() -> None:
    ok, err, _ = parse({
        'S': Seq(Optional(Str('a')), Optional(Str('b')))
    }, '')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e24_zero_or_more_multi() -> None:
    ok, err, _ = parse({'S': ZeroOrMore(Str('x'))}, 'xxx')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e25_one_or_more_multi() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('x'))}, 'xxx')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e26_long_string_match() -> None:
    ok, err, _ = parse({'S': Str('abcdefghij')}, 'abcdefghij')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_e27_long_string_partial() -> None:
    ok, _, _ = parse({'S': Str('abcdefghij')}, 'abcdefghi')
    assert not ok, 'should fail'
