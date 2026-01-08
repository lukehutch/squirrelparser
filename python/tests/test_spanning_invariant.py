"""
Parse Tree Spanning Invariant Tests

These tests verify that Parser.parse() always returns a MatchResult
that completely spans the input (from position 0 to input length).
- Total failures: SyntaxError spanning entire input
- Partial matches: wrapped with trailing SyntaxError
- Complete matches: result spans full input with no wrapper needed
"""

from typing import cast
from collections.abc import Mapping
from squirrelparser import (
    Parser, Clause, Ref, Str,
    Seq, First, OneOrMore, ZeroOrMore, Optional,
    FollowedBy, NotFollowedBy,
    SyntaxError as SyntaxErrorNode
)


def test_span_01_empty_input():
    """Empty input should return SyntaxError spanning empty input"""
    parser = Parser(rules={'S': Str('a')}, input_str='')
    result, _ = parser.parse('S')

    assert isinstance(result, SyntaxErrorNode), 'Empty input with no match should be SyntaxError'
    assert result.len == 0, 'SyntaxError should span full empty input'
    assert result.pos == 0


def test_span_02_complete_match_no_wrapper():
    """Complete match should not be wrapped"""
    parser = Parser(
        rules={'S': Seq(Str('a'), Str('b'), Str('c'))},
        input_str='abc'
    )
    result, _ = parser.parse('S')

    assert not isinstance(result, SyntaxErrorNode), 'Complete match should not be SyntaxError'
    assert result.len == 3, 'Should span entire input'
    assert not result.is_mismatch


def test_span_03_total_failure_returns_syntax_error():
    """Input that doesn't match at all should return SyntaxError spanning all"""
    parser = Parser(rules={'S': Str('a')}, input_str='xyz')
    result, _ = parser.parse('S')

    assert isinstance(result, SyntaxErrorNode), 'Total failure should be SyntaxError'
    assert result.len == 3, 'SyntaxError should span entire input'
    assert result.skipped == 'xyz'


def test_span_04_trailing_garbage_wrapped():
    """Partial match with trailing input should be wrapped with SyntaxError"""
    parser = Parser(
        rules={'S': Seq(Str('a'), Str('b'))},
        input_str='abXYZ'
    )
    result, _ = parser.parse('S')

    assert result.len == 5, 'Result should span entire input'
    assert not isinstance(result, SyntaxErrorNode), 'Result is wrapper Match'

    # Find the trailing SyntaxError in the tree
    def check_for_trailing_error(r):
        if isinstance(r, SyntaxErrorNode):
            if r.pos == 2 and r.len == 3:
                return True
        for child in r.sub_clause_matches:
            if check_for_trailing_error(child):
                return True
        return False

    assert check_for_trailing_error(result), 'Should contain SyntaxError for trailing XYZ'


def test_span_05_single_char_trailing():
    """Single trailing character should be captured"""
    parser = Parser(rules={'S': Str('a')}, input_str='aX')
    result, _ = parser.parse('S')

    assert result.len == 2, 'Should span full input'

    def check_for_trailing_error(r):
        if isinstance(r, SyntaxErrorNode) and r.pos == 1 and r.len == 1:
            return True
        for child in r.sub_clause_matches:
            if check_for_trailing_error(child):
                return True
        return False

    assert check_for_trailing_error(result), 'Should have trailing error'


def test_span_06_multiple_errors_throughout():
    """Multiple errors should all be in parse tree"""
    parser = Parser(
        rules={'S': Seq(Str('a'), Str('b'), Str('c'))},
        input_str='aXbYc'
    )
    result, _ = parser.parse('S')

    assert result.len == 5, 'Should span entire input'

    errors = []
    def collect_errors(r):
        if isinstance(r, SyntaxErrorNode):
            errors.append(r)
        for child in r.sub_clause_matches:
            collect_errors(child)

    collect_errors(result)
    assert len(errors) == 2, 'Should have 2 syntax errors'


def test_span_07_recovery_with_deletion():
    """Deletion at end should be captured"""
    parser = Parser(
        rules={'S': Seq(Str('a'), Str('b'), Str('c'))},
        input_str='ab'
    )
    result, _ = parser.parse('S')

    assert result.len == 2, 'Should span full input (no trailing capture here)'
    assert not isinstance(result, SyntaxErrorNode)


def test_span_08_first_alternative_with_trailing():
    """First should prefer longer match, both may have trailing"""
    parser = Parser(
        rules={
            'S': First(
                Seq(Str('a'), Str('b'), Str('c')),
                Str('a')
            )
        },
        input_str='abcX'
    )
    result, _ = parser.parse('S')

    assert result.len == 4, 'Should span entire input'

    def check_for_x(r):
        if isinstance(r, SyntaxErrorNode) and 'X' in r.skipped:
            return True
        for child in r.sub_clause_matches:
            if check_for_x(child):
                return True
        return False

    assert check_for_x(result), 'Should capture X as error'


def test_span_09_left_recursion_with_trailing():
    """LR expansion with trailing should work"""
    parser = Parser(
        rules={
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            )
        },
        input_str='n+nX'
    )
    result, _ = parser.parse('E')

    assert result.len == 4, 'Should span entire input'

    def check_for_trailing_error(r):
        if isinstance(r, SyntaxErrorNode) and r.pos > 0:
            return True
        for child in r.sub_clause_matches:
            if check_for_trailing_error(child):
                return True
        return False

    assert check_for_trailing_error(result)


def test_span_10_repetition_with_trailing():
    """OneOrMore with trailing should span full input"""
    parser = Parser(
        rules={'S': OneOrMore(Str('a'))},
        input_str='aaaX'
    )
    result, _ = parser.parse('S')

    assert result.len == 4, 'Should span entire input'

    def check_for_trailing_error(r):
        if isinstance(r, SyntaxErrorNode) and 'X' in r.skipped:
            return True
        for child in r.sub_clause_matches:
            if check_for_trailing_error(child):
                return True
        return False

    assert check_for_trailing_error(result)


def test_span_11_nested_rules_with_trailing():
    """Nested rule calls with trailing"""
    parser = Parser(
        rules={
            'S': Seq(Ref('A'), Str(';')),
            'A': Seq(Str('a'), Str('b'))
        },
        input_str='ab;X'
    )
    result, _ = parser.parse('S')

    assert result.len == 4, 'Should span entire input'


def test_span_12_zero_or_more_with_trailing():
    """ZeroOrMore matching nothing, then trailing"""
    parser = Parser(
        rules={'S': ZeroOrMore(Str('a'))},
        input_str='XYZ'
    )
    result, _ = parser.parse('S')

    assert result.len == 3, 'Should span entire input'
    assert not isinstance(result, SyntaxErrorNode)

    def check_for_trailing_error(r):
        if isinstance(r, SyntaxErrorNode):
            return True
        for child in r.sub_clause_matches:
            if check_for_trailing_error(child):
                return True
        return False

    assert check_for_trailing_error(result)


def test_span_13_optional_with_trailing():
    """Optional not matching, then trailing"""
    parser = Parser(
        rules={'S': Optional(Str('a'))},
        input_str='XYZ'
    )
    result, _ = parser.parse('S')

    assert result.len == 3, 'Should span entire input'

    def check_for_trailing_error(r):
        if isinstance(r, SyntaxErrorNode):
            return True
        for child in r.sub_clause_matches:
            if check_for_trailing_error(child):
                return True
        return False

    assert check_for_trailing_error(result)


def test_span_14_followed_by_success_with_trailing():
    """FollowedBy doesn't consume, but trailing should still be captured"""
    parser = Parser(
        rules={
            'S': Seq(
                FollowedBy(Str('a')),
                Str('a'),
                Str('b')
            )
        },
        input_str='abX'
    )
    result, _ = parser.parse('S')

    assert result.len == 3, 'Should span entire input'

    def check_for_trailing_error(r):
        if isinstance(r, SyntaxErrorNode) and 'X' in r.skipped:
            return True
        for child in r.sub_clause_matches:
            if check_for_trailing_error(child):
                return True
        return False

    assert check_for_trailing_error(result)


def test_span_15_not_followed_by_failure_total():
    """NotFollowedBy failing completely should return SyntaxError"""
    parser = Parser(
        rules={
            'S': Seq(NotFollowedBy(Str('x')), Str('y'))
        },
        input_str='xz'
    )
    result, _ = parser.parse('S')

    assert isinstance(result, SyntaxErrorNode), 'Should be total failure'
    assert result.len == 2, 'Should span entire input'


def test_span_16_optional_with_trailing_simple():
    """Optional with trailing - simple case"""
    parser = Parser(
        rules={
            'S': Seq(Str('b'), Optional(Str('c')))
        },
        input_str='bX'
    )
    result, _ = parser.parse('S')

    assert result.len == 2, 'Should span entire input'

    def check_for_trailing_error(r):
        if isinstance(r, SyntaxErrorNode) and 'X' in r.skipped:
            return True
        for child in r.sub_clause_matches:
            if check_for_trailing_error(child):
                return True
        return False

    assert check_for_trailing_error(result)


def test_span_17_invariant_never_null():
    """parse() should never return None - always spans input"""
    test_cases = [
        ({'S': Str('a')}, 'a'),
        ({'S': Str('a')}, 'b'),
        ({'S': Str('a')}, ''),
        ({'S': Seq(Str('a'), Str('b'))}, 'ab'),
        ({'S': Seq(Str('a'), Str('b'))}, 'aXb'),
        ({'S': First(Str('a'), Str('b'))}, 'c'),
    ]

    for rules_dict, input_str in test_cases:
        rules = cast(Mapping[str, Clause], rules_dict)
        parser = Parser(rules=rules, input_str=input_str)
        result, _ = parser.parse('S')

        assert result is not None, f'parse() should never return None for input: {input_str}'
        assert result.len == len(input_str), f'Result should span entire input for: {input_str}'


def test_span_18_long_input_with_single_trailing_error():
    """Long input with single error at end"""
    chars = list('abcdefghijklmnopqrstuvwxyz')
    input_str = 'abcdefghijklmnopqrstuvwxyzX'
    parser = Parser(
        rules={'S': Seq(*[Str(c) for c in chars])},
        input_str=input_str
    )
    result, _ = parser.parse('S')

    assert result.len == 27, 'Should span entire input'

    def check_for_trailing_error(r):
        if isinstance(r, SyntaxErrorNode) and r.pos == 26:
            return True
        for child in r.sub_clause_matches:
            if check_for_trailing_error(child):
                return True
        return False

    assert check_for_trailing_error(result)


def test_span_19_complex_grammar_with_errors():
    """Complex grammar with multiple errors at different levels"""
    parser = Parser(
        rules={
            'S': Seq(Ref('E'), Str(';')),
            'E': First(
                Seq(Ref('E'), Str('+'), Ref('T')),
                Ref('T')
            ),
            'T': Str('n')
        },
        input_str='n+Xn;Y'
    )
    result, _ = parser.parse('S')

    assert result.len == 6, 'Should span entire input'

    errors = []
    def collect_errors(r):
        if isinstance(r, SyntaxErrorNode):
            errors.append(r)
        for child in r.sub_clause_matches:
            collect_errors(child)

    collect_errors(result)
    assert len(errors) >= 2, 'Should capture errors'


def test_span_20_recovery_preserves_matched_content():
    """When recovering from errors, matched content should be preserved"""
    parser = Parser(
        rules={
            'S': Seq(Str('hello'), Str(' '), Str('world'))
        },
        input_str='hello X world'
    )
    result, _ = parser.parse('S')

    assert result.len == 13, 'Should span entire input'
    assert not isinstance(result, SyntaxErrorNode)

    match_count = 0
    has_error = False

    def analyze(r):
        nonlocal match_count, has_error
        if not r.is_mismatch and not isinstance(r, SyntaxErrorNode):
            match_count += 1
        if isinstance(r, SyntaxErrorNode):
            has_error = True
        for child in r.sub_clause_matches:
            analyze(child)

    analyze(result)
    assert has_error, 'Should have error for skipped X'
