"""
SECTION 6: REPETITION COMPREHENSIVE (25 tests)
"""

from squirrelparser import Str, Seq, OneOrMore, ZeroOrMore, Ref, First
from .test_utils import parse


def test_r01_between() -> None:
    ok, err, skip = parse({'S': OneOrMore(Str('ab'))}, 'abXXab')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'XX' in skip, 'should skip XX'


def test_r02_multi() -> None:
    ok, err, skip = parse({'S': OneOrMore(Str('ab'))}, 'abXabYab')
    assert ok, 'should succeed'
    assert err == 2, 'should have 2 errors'
    assert 'X' in skip and 'Y' in skip, 'should skip X and Y'


def test_r03_long_skip() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, 'ab' + 'X' * 50 + 'ab')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'


def test_r04_zero_or_more_start() -> None:
    ok, err, skip = parse({
        'S': Seq(ZeroOrMore(Str('ab')), Str('!'))
    }, 'XXab!')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'XX' in skip, 'should skip XX'


def test_r05_before_first() -> None:
    # FIX #10: OneOrMore now allows first-iteration recovery
    ok, err, skip = parse({'S': OneOrMore(Str('ab'))}, 'XXab')
    assert ok, 'should succeed (skip XX on first iteration)'
    assert err == 1, 'should have 1 error'
    assert 'XX' in skip, 'should skip XX'


def test_r06_trailing_fail() -> None:
    # With new spanning invariant, parser recovers from trailing errors by skipping them
    # The result spans the entire input with a SyntaxError node for the trailing garbage
    ok, err, skip = parse({'S': OneOrMore(Str('ab'))}, 'ababXX')
    assert ok, 'should succeed (trailing error recovered via skip)'
    assert err == 1, 'should have 1 error (trailing XX)'
    assert 'XX' in skip, 'should skip XX'


def test_r07_single() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, 'ab')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_r08_zero_or_more_empty() -> None:
    ok, err, _ = parse({'S': ZeroOrMore(Str('ab'))}, '')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_r09_alternating() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, 'abXabXabXab')
    assert ok, 'should succeed'
    assert err == 3, 'should have 3 errors'


def test_r10_long_clean() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('x'))}, 'x' * 100)
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_r11_long_err() -> None:
    ok, err, skip = parse({'S': OneOrMore(Str('x'))}, 'x' * 50 + 'Z' + 'x' * 49)
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'Z' in skip, 'should skip Z'


def test_r12_20_errors() -> None:
    input_str = ''.join(['abZ'] * 20) + 'ab'
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, input_str)
    assert ok, 'should succeed'
    assert err == 20, 'should have 20 errors'


def test_r13_very_long() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, 'ab' * 500)
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_r14_very_long_err() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, 'ab' * 250 + 'ZZ' + 'ab' * 249)
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'


def test_r15_trailing_single_char_after_recovery() -> None:
    ok, err, skip = parse(
        {'S': Seq(Ref('A')), 'A': OneOrMore(First(Str('a'), Str('b')))},
        'abxbxax'
    )
    assert ok, 'should succeed'
    assert err == 3, f'should have 3 errors, got {err}'
    assert len(skip) == 3, f'should have 3 skipped items, got {len(skip)}'


def test_r16_trailing_multiple_chars_after_recovery() -> None:
    ok, err, skip = parse({'S': OneOrMore(Str('ab'))}, 'abXabXabXX')
    assert ok, 'should succeed'
    assert err == 3, f'should have 3 errors, got {err}'
    assert len(skip) == 3, f'should have 3 skipped items, got {len(skip)}'


def test_r17_trailing_long_error_after_recovery() -> None:
    ok, err, _ = parse(
        {'S': OneOrMore(Str('x'))},
        'x' * 50 + 'Z' + 'x' * 49 + 'YYYY'
    )
    assert ok, 'should succeed'
    assert err == 2, f'should have 2 errors, got {err}'


def test_r18_trailing_after_multiple_alternating_errors() -> None:
    ok, err, skip = parse({'S': OneOrMore(Str('ab'))}, 'abXabYabZabXX')
    assert ok, 'should succeed'
    assert err == 4, f'should have 4 errors, got {err}'
    assert len(skip) == 4, f'should have 4 skipped items, got {len(skip)}'


def test_r19_single_char_after_first_recovery() -> None:
    ok, err, skip = parse({'S': OneOrMore(Str('ab'))}, 'XXabX')
    assert ok, 'should succeed'
    assert err == 2, f'should have 2 errors, got {err}'
    assert len(skip) == 2, f'should have 2 skipped items, got {len(skip)}'


def test_r20_trailing_error_with_single_element() -> None:
    ok, err, skip = parse({'S': OneOrMore(Str('a'))}, 'aXaY')
    assert ok, 'should succeed'
    assert err == 2, f'should have 2 errors, got {err}'
    assert len(skip) == 2, f'should have 2 skipped items, got {len(skip)}'
