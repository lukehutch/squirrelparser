"""
ONEORMORE FIRST-ITERATION RECOVERY TESTS (FIX #10 Verification)

These tests verify that OneOrMore allows recovery on the first iteration
while still maintaining "at least one match" semantics.
"""

from squirrelparser import Str, Seq, OneOrMore, ZeroOrMore
from .test_utils import parse


def test_om_01_first_clean() -> None:
    # Baseline: First iteration succeeds cleanly
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, 'ababab')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_om_02_no_match_anywhere() -> None:
    # OneOrMore still requires at least one match
    ok, _, _ = parse({'S': OneOrMore(Str('ab'))}, 'xyz')
    assert not ok, 'should fail (no match found)'


def test_om_03_skip_to_first_match() -> None:
    # FIX #10: Skip garbage to find first match
    ok, err, skip = parse({'S': OneOrMore(Str('ab'))}, 'Xab')
    assert ok, 'should succeed (skip X on first iteration)'
    assert err == 1, 'should have 1 error'
    assert 'X' in skip, 'should skip X'


def test_om_04_skip_multiple_to_first() -> None:
    # FIX #10: Skip multiple characters to find first match
    ok, err, skip = parse({'S': OneOrMore(Str('ab'))}, 'XXXXXab')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error (entire skip)'
    assert 'XXXXX' in skip, 'should skip XXXXX'


def test_om_05_multiple_iterations_with_errors() -> None:
    # FIX #10: First iteration with error, then more iterations with errors
    ok, err, skip = parse({'S': OneOrMore(Str('ab'))}, 'XabYabZab')
    assert ok, 'should succeed'
    assert err == 3, 'should have 3 errors'
    assert 'X' in skip, 'should skip X'
    assert 'Y' in skip, 'should skip Y'
    assert 'Z' in skip, 'should skip Z'


def test_om_06_first_with_error_then_clean() -> None:
    # First iteration skips error, subsequent iterations clean
    ok, err, skip = parse({'S': OneOrMore(Str('ab'))}, 'Xabababab')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error (only X)'
    assert 'X' in skip, 'should skip X'


def test_om_07_vs_zeoormore_semantics() -> None:
    # BOTH ZeroOrMore and OneOrMore fail on input with no matches
    # because parseWithRecovery requires parsing the ENTIRE input.
    # ZeroOrMore matches 0 times (len=0), leaving "XYZ" unparsed.
    # OneOrMore matches 0 times (fails "at least one"), also leaving input unparsed.

    # Key difference: Empty input
    ok1, err1, _ = parse({'S': ZeroOrMore(Str('ab'))}, '')
    assert ok1, 'ZeroOrMore should succeed on empty input'
    assert err1 == 0, 'should have 0 errors'

    ok2, _, _ = parse({'S': OneOrMore(Str('ab'))}, '')
    assert not ok2, 'OneOrMore should fail on empty input'

    # Key difference: With valid matches
    ok3, _, _ = parse({'S': ZeroOrMore(Str('ab'))}, 'ababab')
    assert ok3, 'ZeroOrMore succeeds with matches'

    ok4, _, _ = parse({'S': OneOrMore(Str('ab'))}, 'ababab')
    assert ok4, 'OneOrMore succeeds with matches'


def test_om_08_long_skip_performance() -> None:
    # Large skip distance should still complete quickly
    input_str = 'X' * 100 + 'ab'
    ok, err, skip = parse({'S': OneOrMore(Str('ab'))}, input_str)
    assert ok, 'should succeed (performance test)'
    assert err == 1, 'should have 1 error'
    assert len(skip[0]) == 100, "should skip 100 X's"


def test_om_09_exhaustive_search_no_match() -> None:
    # Try all positions, find nothing, fail cleanly
    input_str = 'X' * 50 + 'Y' * 50  # No 'ab' anywhere
    ok, _, _ = parse({'S': OneOrMore(Str('ab'))}, input_str)
    assert not ok, 'should fail (exhaustive search finds nothing)'


def test_om_10_first_iteration_with_bound() -> None:
    # First iteration recovery + bound checking
    ok, err, skip = parse({
        'S': Seq(OneOrMore(Str('ab')), Str('end'))
    }, 'XabYabend')
    assert ok, 'should succeed'
    assert err == 2, 'should have 2 errors (X and Y)'
    assert 'X' in skip, 'should skip X'
    assert 'Y' in skip, 'should skip Y'


def test_om_11_alternating_pattern() -> None:
    # Pattern: error, match, error, match, ...
    ok, err, _ = parse({'S': OneOrMore(Str('ab'))}, 'XabXabXabXab')
    assert ok, 'should succeed'
    assert err == 4, "should have 4 errors (4 X's)"


def test_om_12_multi_char_terminal_first() -> None:
    # Multi-character terminal with first-iteration recovery
    ok, err, skip = parse({'S': OneOrMore(Str('hello'))}, 'XXXhellohello')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'XXX' in skip, 'should skip XXX'
