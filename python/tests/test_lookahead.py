"""
Lookahead Operators Tests
"""

from typing import cast, Mapping
from squirrelparser import (
    Parser, Str, Char, CharRange, AnyChar, Seq, First,
    OneOrMore, ZeroOrMore, Ref, FollowedBy, NotFollowedBy, Clause
)


# ===========================================================================
# Lookahead Operators - Direct Matching
# ===========================================================================

# FollowedBy (&)

def test_positive_lookahead_succeeds_when_pattern_matches() -> None:
    rules: dict[str, Clause] = {
        'Test': FollowedBy(Str('a')),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='abc')
    result = parser.match(rules['Test'], 0)

    assert not result.is_mismatch
    assert result.len == 0  # Lookahead doesn't consume


def test_positive_lookahead_fails_when_pattern_does_not_match() -> None:
    rules: dict[str, Clause] = {
        'Test': FollowedBy(Str('a')),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='b')
    result = parser.match(rules['Test'], 0)

    assert result.is_mismatch


def test_positive_lookahead_in_sequence() -> None:
    rules: dict[str, Clause] = {
        'Test': Seq(Str('a'), FollowedBy(Str('b'))),
    }

    # Should match 'a' and check for 'b', consuming only 'a'
    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='abc')
    result = parser.match(rules['Test'], 0)

    assert not result.is_mismatch
    assert result.len == 1  # Only 'a' consumed


def test_positive_lookahead_in_sequence_fails_when_not_followed() -> None:
    rules: dict[str, Clause] = {
        'Test': Seq(Str('a'), FollowedBy(Str('b'))),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='ac')
    result = parser.match(rules['Test'], 0)

    assert result.is_mismatch  # Fails because no 'b' after 'a'


def test_positive_lookahead_with_continuation() -> None:
    rules: dict[str, Clause] = {
        'Test': Seq(Str('a'), FollowedBy(Str('b')), Str('b')),
    }

    # Should match 'a', check for 'b', then consume 'b'
    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='abc')
    result = parser.match(rules['Test'], 0)

    assert not result.is_mismatch
    assert result.len == 2  # 'a' and 'b' consumed


def test_positive_lookahead_at_end_of_input() -> None:
    rules: dict[str, Clause] = {
        'Test': Seq(Str('a'), FollowedBy(Str('b'))),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='a')
    result = parser.match(rules['Test'], 0)

    assert result.is_mismatch  # No 'b' to look ahead to


def test_nested_positive_lookaheads() -> None:
    rules: dict[str, Clause] = {
        'Test': Seq(
            FollowedBy(FollowedBy(Str('a'))),
            Str('a'),
        ),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='a')
    result = parser.match(rules['Test'], 0)

    assert not result.is_mismatch
    assert result.len == 1


# NotFollowedBy (!)

def test_negative_lookahead_succeeds_when_pattern_does_not_match() -> None:
    rules: dict[str, Clause] = {
        'Test': NotFollowedBy(Str('a')),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='b')
    result = parser.match(rules['Test'], 0)

    assert not result.is_mismatch
    assert result.len == 0  # Lookahead doesn't consume


def test_negative_lookahead_fails_when_pattern_matches() -> None:
    rules: dict[str, Clause] = {
        'Test': NotFollowedBy(Str('a')),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='a')
    result = parser.match(rules['Test'], 0)

    assert result.is_mismatch


def test_negative_lookahead_in_sequence() -> None:
    rules: dict[str, Clause] = {
        'Test': Seq(Str('a'), NotFollowedBy(Str('b'))),
    }

    # Should match 'a' when NOT followed by 'b'
    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='ac')
    result = parser.match(rules['Test'], 0)

    assert not result.is_mismatch
    assert result.len == 1  # Only 'a' consumed


def test_negative_lookahead_in_sequence_fails_when_followed() -> None:
    rules: dict[str, Clause] = {
        'Test': Seq(Str('a'), NotFollowedBy(Str('b'))),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='ab')
    result = parser.match(rules['Test'], 0)

    assert result.is_mismatch  # Fails because 'a' IS followed by 'b'


def test_negative_lookahead_with_continuation() -> None:
    rules: dict[str, Clause] = {
        'Test': Seq(Str('a'), NotFollowedBy(Str('b')), Str('c')),
    }

    # Should match 'a', check NOT 'b', then consume 'c'
    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='ac')
    result = parser.match(rules['Test'], 0)

    assert not result.is_mismatch
    assert result.len == 2  # 'a' and 'c' consumed


def test_negative_lookahead_at_end_of_input() -> None:
    rules: dict[str, Clause] = {
        'Test': Seq(Str('a'), NotFollowedBy(Str('b'))),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='a')
    result = parser.match(rules['Test'], 0)

    assert not result.is_mismatch  # No 'b' following, so succeeds
    assert result.len == 1


def test_nested_negative_lookaheads() -> None:
    rules: dict[str, Clause] = {
        # !!"a" is the same as &"a"
        'Test': Seq(
            NotFollowedBy(NotFollowedBy(Str('a'))),
            Str('a'),
        ),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='a')
    result = parser.match(rules['Test'], 0)

    assert not result.is_mismatch
    assert result.len == 1


# Mixed Lookaheads

def test_positive_then_negative_lookahead() -> None:
    rules: dict[str, Clause] = {
        'Test': Seq(
            FollowedBy(CharRange('a', 'z')),
            NotFollowedBy(Str('x')),
            CharRange('a', 'z'),
        ),
    }

    # Should match any lowercase letter except 'x'
    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='a')
    result = parser.match(rules['Test'], 0)
    assert not result.is_mismatch

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='x')
    result = parser.match(rules['Test'], 0)
    assert result.is_mismatch

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='A')
    result = parser.match(rules['Test'], 0)
    assert result.is_mismatch


def test_lookahead_in_choice() -> None:
    rules: dict[str, Clause] = {
        'Test': First(
            Seq(FollowedBy(Str('a')), Str('a')),
            Seq(FollowedBy(Str('b')), Str('b')),
        ),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='a')
    result = parser.match(rules['Test'], 0)
    assert not result.is_mismatch
    assert result.len == 1

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='b')
    result = parser.match(rules['Test'], 0)
    assert not result.is_mismatch
    assert result.len == 1

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='c')
    result = parser.match(rules['Test'], 0)
    assert result.is_mismatch


def test_lookahead_with_repetition() -> None:
    rules: dict[str, Clause] = {
        'Test': ZeroOrMore(Seq(
            NotFollowedBy(Str('.')),
            CharRange('a', 'z'),
        )),
    }

    # Match lowercase letters until '.'
    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='abc.def')
    result = parser.match(rules['Test'], 0)
    assert not result.is_mismatch
    assert result.len == 3  # 'abc'

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='.abc')
    result = parser.match(rules['Test'], 0)
    assert not result.is_mismatch
    assert result.len == 0  # Stops immediately at '.'


# Lookahead with References

def test_positive_lookahead_with_rule_reference() -> None:
    rules: dict[str, Clause] = {
        'Digit': CharRange('0', '9'),
        'Test': Seq(
            FollowedBy(Ref('Digit')),
            Ref('Digit'),
        ),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='5')
    result = parser.match(rules['Test'], 0)

    assert not result.is_mismatch
    assert result.len == 1


def test_negative_lookahead_with_rule_reference() -> None:
    rules: dict[str, Clause] = {
        'Digit': CharRange('0', '9'),
        'Test': Seq(
            NotFollowedBy(Ref('Digit')),
            CharRange('a', 'z'),
        ),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='a')
    result = parser.match(rules['Test'], 0)
    assert not result.is_mismatch

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='5')
    result = parser.match(rules['Test'], 0)
    assert result.is_mismatch


# ===========================================================================
# Lookahead Operators - Integration with parse()
# ===========================================================================

def test_lookahead_with_full_input_consumption() -> None:
    rules: dict[str, Clause] = {
        'Test': Seq(Str('a'), FollowedBy(Str('b')), Str('b')),
    }

    # Should match and consume all input
    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='ab')
    result, used_recovery = parser.parse('Test')

    assert result is not None
    assert result.len == 2  # Both 'a' and 'b' consumed


def test_negative_lookahead_with_full_input_consumption() -> None:
    rules: dict[str, Clause] = {
        'Test': Seq(Str('a'), NotFollowedBy(Str('b')), Str('c')),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='ac')
    result, used_recovery = parser.parse('Test')

    assert result is not None
    assert result.len == 2  # 'a' and 'c' consumed


def test_identifier_parser_with_lookahead_valid() -> None:
    # Parse identifiers that don't start with a digit
    rules: dict[str, Clause] = {
        'Identifier': Seq(
            NotFollowedBy(CharRange('0', '9')),
            OneOrMore(First(
                CharRange('a', 'z'),
                CharRange('A', 'Z'),
                CharRange('0', '9'),
                Char('_'),
            )),
        ),
    }

    # Valid identifier (all input consumed)
    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='abc123')
    result, used_recovery = parser.parse('Identifier')
    assert result is not None
    assert result.len == 6


def test_identifier_parser_with_lookahead_using_match() -> None:
    # Parse identifiers that don't start with a digit
    rules: dict[str, Clause] = {
        'Identifier': Seq(
            NotFollowedBy(CharRange('0', '9')),
            OneOrMore(First(
                CharRange('a', 'z'),
                CharRange('A', 'Z'),
                CharRange('0', '9'),
                Char('_'),
            )),
        ),
    }

    # Test with match to avoid recovery
    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='123abc')
    result = parser.match(rules['Identifier'], 0)
    assert result.is_mismatch  # Starts with digit, should fail


def test_keyword_vs_identifier_with_lookahead() -> None:
    # Parse 'if' only when not followed by alphanumeric (i.e., as keyword)
    rules: dict[str, Clause] = {
        'Keyword': Seq(
            Str('if'),
            NotFollowedBy(First(
                CharRange('a', 'z'),
                CharRange('A', 'Z'),
                CharRange('0', '9'),
                Char('_'),
            )),
        ),
    }

    # Valid keyword (all input consumed)
    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='if')
    result, used_recovery = parser.parse('Keyword')
    assert result is not None  # 'if' as keyword
    assert result.len == 2

    # Invalid - 'ifx' is not just 'if'
    # With spanning invariant, parser recovers and skips the remaining 'x'
    from squirrelparser import SyntaxError as SyntaxErrorNode
    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='ifx')
    result, used_recovery = parser.parse('Keyword')
    # The lookahead fails on 'x', but parser recovers with SyntaxError
    assert isinstance(result, SyntaxErrorNode), 'lookahead fails on "ifx", total failure'


def test_comment_parser_with_lookahead() -> None:
    # Parse // style comments until end of line
    rules: dict[str, Clause] = {
        'Comment': Seq(
            Str('//'),
            ZeroOrMore(Seq(
                NotFollowedBy(Char('\n')),
                AnyChar(),
            )),
            Char('\n'),
        ),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='//hello world\n')
    result, used_recovery = parser.parse('Comment')
    assert result is not None
    assert result.len == 14  # All input consumed


def test_string_literal_parser_with_lookahead() -> None:
    # Parse string literals with escape sequences
    rules: dict[str, Clause] = {
        'String': Seq(
            Char('"'),
            ZeroOrMore(First(
                Seq(Str('\\'), AnyChar()),  # Escape sequence
                Seq(NotFollowedBy(Char('"')), AnyChar()),  # Non-quote char
            )),
            Char('"'),
        ),
    }

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='"hello"')
    result, used_recovery = parser.parse('String')
    assert result is not None

    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str='"hello\\"world"')
    result, used_recovery = parser.parse('String')
    assert result is not None
