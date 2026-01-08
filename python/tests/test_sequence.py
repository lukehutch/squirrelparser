"""
SECTION 7: SEQUENCE COMPREHENSIVE (20 tests)
"""

from squirrelparser import Parser, Str, Seq
from .test_utils import parse, count_deletions


def test_s01_2_elem() -> None:
    ok, err, _ = parse({
        'S': Seq(Str('a'), Str('b'))
    }, 'ab')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_s02_3_elem() -> None:
    ok, err, _ = parse({
        'S': Seq(Str('a'), Str('b'), Str('c'))
    }, 'abc')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_s03_5_elem() -> None:
    ok, err, _ = parse({
        'S': Seq(Str('a'), Str('b'), Str('c'), Str('d'), Str('e'))
    }, 'abcde')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_s04_insert_mid() -> None:
    ok, err, skip = parse({
        'S': Seq(Str('a'), Str('b'), Str('c'))
    }, 'aXXbc')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'XX' in skip, 'should skip XX'


def test_s05_insert_end() -> None:
    ok, err, skip = parse({
        'S': Seq(Str('a'), Str('b'), Str('c'))
    }, 'abXXc')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'XX' in skip, 'should skip XX'


def test_s06_del_mid() -> None:
    # Cannot delete grammar elements mid-parse (Fix #8 - Visibility Constraint)
    # Input "ac" with grammar "a" "b" "c" would require deleting "b" at position 1
    # Position 1 is not EOF (still have "c" to parse), so this violates constraints
    parser = Parser(
        rules={
            'S': Seq(Str('a'), Str('b'), Str('c'))
        },
        input_str='ac',
    )
    result, used_recovery = parser.parse('S')
    # Should fail - cannot delete "b" mid-parse
    from squirrelparser import SyntaxError as SyntaxErrorNode
    assert isinstance(result, SyntaxErrorNode), \
        'should fail (mid-parse grammar deletion violates Visibility Constraint)'


def test_s07_del_end() -> None:
    parser = Parser(
        rules={
            'S': Seq(Str('a'), Str('b'), Str('c'))
        },
        input_str='ab',
    )
    result, used_recovery = parser.parse('S')
    assert result is not None and not result.is_mismatch, 'should succeed'
    assert count_deletions(result) == 1, 'should have 1 deletion'


def test_s08_nested_clean() -> None:
    ok, err, _ = parse({
        'S': Seq(
            Seq(Str('a'), Str('b')),
            Str('c')
        )
    }, 'abc')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_s09_nested_insert() -> None:
    ok, err, skip = parse({
        'S': Seq(
            Seq(Str('a'), Str('b')),
            Str('c')
        )
    }, 'aXbc')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'X' in skip, 'should skip X'


def test_s10_long_seq_clean() -> None:
    clauses = [Str(c) for c in 'abcdefghijklmnop']
    ok, err, _ = parse({'S': Seq(*clauses)}, 'abcdefghijklmnop')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
