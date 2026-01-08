"""
OPTIONAL WITH RECOVERY TESTS

These tests verify Optional behavior with and without recovery.
"""

from squirrelparser import Str, Seq, First, OneOrMore, ZeroOrMore, Optional
from .test_utils import parse


def test_opt_01_optional_matches_cleanly() -> None:
    # Optional matches its content cleanly
    ok, err, _ = parse({
        'S': Seq(Optional(Str('a')), Str('b'))
    }, 'ab')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
    # Optional matches 'a', then 'b'


def test_opt_02_optional_falls_through_cleanly() -> None:
    # Optional doesn't match, falls through
    ok, err, _ = parse({
        'S': Seq(Optional(Str('a')), Str('b'))
    }, 'b')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
    # Optional returns empty match (len=0), then 'b' matches


def test_opt_03_optional_with_recovery_attempt() -> None:
    # Optional content needs recovery - should Optional try recovery or fall through?
    # Current behavior: Optional tries recovery
    ok, err, skip = parse({
        'S': Optional(Seq(Str('a'), Str('b')))
    }, 'aXb')
    assert ok, 'should succeed'
    # If Optional attempts recovery: err=1, skip=['X']
    # If Optional falls through: err=0, but incomplete parse
    assert err == 1, 'Optional should attempt recovery'
    assert 'X' in skip, 'should skip X'


def test_opt_04_optional_in_sequence() -> None:
    # Optional in middle of sequence
    ok, err, _ = parse({
        'S': Seq(Str('a'), Optional(Str('b')), Str('c'))
    }, 'ac')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
    # 'a' matches, Optional falls through, 'c' matches


def test_opt_05_nested_optional() -> None:
    # Optional(Optional(...))
    ok, err, _ = parse({
        'S': Seq(Optional(Optional(Str('a'))), Str('b'))
    }, 'b')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
    # Both optionals return empty


def test_opt_06_optional_with_first() -> None:
    # Optional(First([...]))
    ok, err, _ = parse({
        'S': Seq(
            Optional(First(Str('a'), Str('b'))),
            Str('c')
        )
    }, 'bc')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
    # Optional matches First's second alternative 'b'


def test_opt_07_optional_with_repetition() -> None:
    # Optional(OneOrMore(...))
    ok, err, _ = parse({
        'S': Seq(Optional(OneOrMore(Str('x'))), Str('y'))
    }, 'xxxy')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
    # Optional matches OneOrMore which matches 3 x's


def test_opt_08_optional_at_eof() -> None:
    # Optional at end of grammar
    ok, err, _ = parse({
        'S': Seq(Str('a'), Optional(Str('b')))
    }, 'a')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
    # 'a' matches, Optional at EOF returns empty


def test_opt_09_multiple_optionals() -> None:
    # Multiple optionals in sequence
    ok, err, _ = parse({
        'S': Seq(Optional(Str('a')), Optional(Str('b')), Str('c'))
    }, 'c')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
    # Both optionals return empty, 'c' matches


def test_opt_10_optional_vs_zeoormore() -> None:
    # Optional(Str(x)) vs ZeroOrMore(Str(x))
    # Optional: matches 0 or 1 time
    # ZeroOrMore: matches 0 or more times
    ok1, err1, _ = parse({
        'S': Seq(Optional(Str('x')), Str('y'))
    }, 'xxxy')
    # Optional matches first 'x', remaining "xxy" for rest
    # Str('y') sees "xxy", uses recovery to skip "xx", matches 'y'
    assert ok1, 'Optional matches 1, recovery handles rest'
    assert err1 == 1, 'should have 1 error (skipped xx)'

    ok2, err2, _ = parse({
        'S': Seq(ZeroOrMore(Str('x')), Str('y'))
    }, 'xxxy')
    assert ok2, 'ZeroOrMore matches all 3, then y'
    assert err2 == 0, 'should have 0 errors (clean match)'


def test_opt_11_optional_with_complex_content() -> None:
    # Optional(Seq([complex structure]))
    ok, err, _ = parse({
        'S': Seq(
            Optional(Seq(Str('if'), Str('('), Str('x'), Str(')'))),
            Str('body')
        )
    }, 'if(x)body')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_opt_12_optional_incomplete_phase1() -> None:
    # In Phase 1, if Optional's content is incomplete, should Optional be marked incomplete?
    # This is testing the "mark Optional fallback incomplete" (Modification 5)
    ok, _, _ = parse({
        'S': Seq(Optional(Str('a')), Str('b'))
    }, 'Xb')
    # Phase 1: Optional tries 'a' at 0, sees 'X', fails
    #   Optional falls through (returns empty), marked incomplete
    # Phase 2: Re-evaluates, Optional might try recovery? Or still fall through?
    assert ok, 'should succeed'
    # If Optional tries recovery in Phase 2, would skip X and fail to find 'a'
    # Then falls through, 'b' matches
