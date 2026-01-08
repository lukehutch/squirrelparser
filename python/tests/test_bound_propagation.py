"""
BOUND PROPAGATION TESTS (FIX #9 Verification)

These tests verify that bounds propagate through arbitrary nesting levels
to correctly stop repetitions before consuming delimiters.
"""

from squirrelparser import Str, Seq, First, OneOrMore, ZeroOrMore, Ref
from .test_utils import parse


def test_bp_01_direct_repetition() -> None:
    # Baseline: Bound with direct Repetition child (was already working)
    ok, err, _ = parse({
        'S': Seq(OneOrMore(Str('x')), Str('end'))
    }, 'xxxxend')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_bp_02_through_ref() -> None:
    # FIX #9: Bound propagates through Ref
    ok, err, _ = parse({
        'S': Seq(Ref('A'), Str('end')),
        'A': OneOrMore(Str('x')),
    }, 'xxxxend')
    assert ok, 'should succeed (bound through Ref)'
    assert err == 0, 'should have 0 errors'


def test_bp_03_through_nested_refs() -> None:
    # FIX #9: Bound propagates through multiple Refs
    ok, err, _ = parse({
        'S': Seq(Ref('A'), Str('end')),
        'A': Ref('B'),
        'B': OneOrMore(Str('x')),
    }, 'xxxxend')
    assert ok, 'should succeed (bound through 2 Refs)'
    assert err == 0, 'should have 0 errors'


def test_bp_04_through_first() -> None:
    # FIX #9: Bound propagates through First alternatives
    ok, err, _ = parse({
        'S': Seq(Ref('A'), Str('end')),
        'A': First(OneOrMore(Str('x')), OneOrMore(Str('y'))),
    }, 'xxxxend')
    assert ok, 'should succeed (bound through First)'
    assert err == 0, 'should have 0 errors'


def test_bp_05_left_recursive_with_repetition() -> None:
    # FIX #9: The EMERG-01 case - bound through LR + First + Seq + Repetition
    ok, err, _ = parse({
        'S': Seq(Ref('E'), Str('end')),
        'E': First(
            Seq(Ref('E'), Str('+'), OneOrMore(Str('n'))),
            Str('n')
        ),
    }, 'n+nnn+nnend')
    assert ok, 'should succeed (bound through LR)'
    assert err == 0, 'should have 0 errors'


def test_bp_06_with_recovery_inside_bounded_rep() -> None:
    # FIX #9 + recovery: Bound propagates AND recovery works inside repetition
    ok, err, skip = parse({
        'S': Seq(Ref('A'), Str('end')),
        'A': OneOrMore(Str('ab')),
    }, 'abXabYabend')
    assert ok, 'should succeed'
    assert err == 2, 'should have 2 errors (X and Y)'
    assert 'X' in skip, 'should skip X'
    assert 'Y' in skip, 'should skip Y'


def test_bp_07_multiple_bounds_nested_seq() -> None:
    # Multiple bounds in nested Seq structures
    ok, err, _ = parse({
        'S': Seq(Ref('A'), Str(';'), Ref('B'), Str('end')),
        'A': OneOrMore(Str('x')),
        'B': OneOrMore(Str('y')),
    }, 'xxxx;yyyyend')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
    # A stops at ';', B stops at 'end'


def test_bp_08_bound_vs_eof() -> None:
    # Without explicit bound, should consume until EOF
    ok, err, _ = parse({'S': OneOrMore(Str('x'))}, 'xxxx')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
    # No bound, so consumes all x's


def test_bp_09_zeoormore_with_bound() -> None:
    # Bound applies to ZeroOrMore too
    ok, err, _ = parse({
        'S': Seq(ZeroOrMore(Str('x')), Str('end'))
    }, 'end')
    assert ok, 'should succeed (ZeroOrMore matches 0)'
    assert err == 0, 'should have 0 errors'


def test_bp_10_complex_nesting() -> None:
    # Deeply nested: Ref → First → Seq → Ref → Repetition
    ok, err, _ = parse({
        'S': Seq(Ref('A'), Str('end')),
        'A': First(
            Seq(Str('a'), Ref('B')),
            Str('fallback')
        ),
        'B': OneOrMore(Str('x')),
    }, 'axxxxend')
    assert ok, 'should succeed (bound through complex nesting)'
    assert err == 0, 'should have 0 errors'
