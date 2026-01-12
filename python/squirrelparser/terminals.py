"""Terminal clauses for the parser."""

from __future__ import annotations
from abc import ABC
from typing import TYPE_CHECKING

from .clause import Clause
from .match_result import Match, mismatch, MatchResult
from .utils import escape_string

if TYPE_CHECKING:
    from .parser import Parser


class Terminal(Clause, ABC):
    """Abstract base class for terminal clauses."""

    # The AST/CST node label for terminals.
    node_label: str = '<Terminal>'

    def check_rule_refs(self, grammar_map: dict[str, Clause]) -> None:
        # Terminals have no references to check.
        pass


# ------------------------------------------------------------------------------------------------------------------


class Str(Terminal):
    """Matches a literal string."""

    __slots__ = ('text',)

    def __init__(self, text: str) -> None:
        self.text = text

    def match(self, parser: Parser, pos: int, *, bound: Clause | None = None) -> MatchResult:
        if pos + len(self.text) > len(parser.input):
            return mismatch
        for i in range(len(self.text)):
            if parser.input[pos + i] != self.text[i]:
                return mismatch
        return Match(self, pos, len(self.text))

    def __repr__(self) -> str:
        return f'"{escape_string(self.text)}"'


# ------------------------------------------------------------------------------------------------------------------


class Char(Terminal):
    """Matches a single character."""

    __slots__ = ('char',)

    def __init__(self, char: str) -> None:
        if len(char) != 1:
            raise ValueError('Char must be a single character')
        self.char = char

    def match(self, parser: Parser, pos: int, *, bound: Clause | None = None) -> MatchResult:
        if pos + len(self.char) > len(parser.input):
            return mismatch
        for i in range(len(self.char)):
            if parser.input[pos + i] != self.char[i]:
                return mismatch
        return Match(self, pos, len(self.char))

    def __repr__(self) -> str:
        return f"'{escape_string(self.char)}'"


# ------------------------------------------------------------------------------------------------------------------


class CharSet(Terminal):
    """
    Matches a single character in a set of character ranges.

    Supports multiple ranges and an optional inversion flag for negated character
    classes like `[^a-zA-Z0-9]`.
    """

    __slots__ = ('ranges', 'inverted')

    def __init__(self, ranges: list[tuple[int, int]], *, inverted: bool = False) -> None:
        """Create a CharSet from a list of (lo, hi) code unit ranges (inclusive)."""
        self.ranges = ranges
        self.inverted = inverted

    @classmethod
    def range(cls, lo: str, hi: str) -> CharSet:
        """Convenience factory for a single character range."""
        return cls([(ord(lo), ord(hi))], inverted=False)

    @classmethod
    def char(cls, c: str) -> CharSet:
        """Convenience factory for a single character."""
        cp = ord(c)
        return cls([(cp, cp)], inverted=False)

    @classmethod
    def not_range(cls, lo: str, hi: str) -> CharSet:
        """Convenience factory for a negated single character range."""
        return cls([(ord(lo), ord(hi))], inverted=True)

    def match(self, parser: Parser, pos: int, *, bound: Clause | None = None) -> MatchResult:
        if pos >= len(parser.input):
            return mismatch
        c = ord(parser.input[pos])

        in_set = False
        for lo, hi in self.ranges:
            if lo <= c <= hi:
                in_set = True
                break

        if (not in_set) if self.inverted else in_set:
            return Match(self, pos, 1)
        return mismatch

    def __repr__(self) -> str:
        parts: list[str] = ['[']
        if self.inverted:
            parts.append('^')
        for lo, hi in self.ranges:
            if lo == hi:
                parts.append(escape_string(chr(lo)))
            else:
                parts.append(escape_string(chr(lo)))
                parts.append('-')
                parts.append(escape_string(chr(hi)))
        parts.append(']')
        return ''.join(parts)


# ------------------------------------------------------------------------------------------------------------------


class AnyChar(Terminal):
    """Matches any single character."""

    def match(self, parser: Parser, pos: int, *, bound: Clause | None = None) -> MatchResult:
        if pos >= len(parser.input):
            return mismatch
        return Match(self, pos, 1)

    def __repr__(self) -> str:
        return '.'


# ------------------------------------------------------------------------------------------------------------------


class Nothing(Terminal):
    """Matches nothing - always succeeds without consuming any input."""

    def match(self, parser: Parser, pos: int, *, bound: Clause | None = None) -> MatchResult:
        return Match(self, pos, 0)

    def __repr__(self) -> str:
        return '()'
