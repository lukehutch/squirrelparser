"""Terminal clause implementations for the Squirrel Parser."""

from __future__ import annotations
from dataclasses import dataclass
from typing import TYPE_CHECKING

from .match_result import Match, MISMATCH

if TYPE_CHECKING:
    from .clause import Clause
    from .match_result import MatchResult
    from .parser import Parser


@dataclass(frozen=True, slots=True)
class Str:
    """Matches a literal string."""

    text: str
    transparent: bool = False

    def match(self, parser: Parser, pos: int, bound: Clause | None = None) -> MatchResult:
        if pos + len(self.text) > len(parser.input):
            return MISMATCH
        for i, ch in enumerate(self.text):
            if parser.input[pos + i] != ch:
                return MISMATCH
        return Match(self, pos, len(self.text))

    def __str__(self) -> str:
        return f'"{self.text}"'


@dataclass(frozen=True, slots=True)
class Char:
    """Matches a single character."""

    ch: str
    transparent: bool = False

    def __post_init__(self) -> None:
        if len(self.ch) != 1:
            raise ValueError("Char must be exactly one character")

    def match(self, parser: Parser, pos: int, bound: Clause | None = None) -> MatchResult:
        if pos >= len(parser.input):
            return MISMATCH
        if parser.input[pos] == self.ch:
            return Match(self, pos, 1)
        return MISMATCH

    def __str__(self) -> str:
        return f"'{self.ch}'"


@dataclass(frozen=True, slots=True)
class CharRange:
    """Matches a single character in a range [lo-hi]."""

    lo: str
    hi: str
    transparent: bool = False

    def __post_init__(self) -> None:
        if len(self.lo) != 1 or len(self.hi) != 1:
            raise ValueError("CharRange bounds must be single characters")

    def match(self, parser: Parser, pos: int, bound: Clause | None = None) -> MatchResult:
        if pos >= len(parser.input):
            return MISMATCH
        ch = parser.input[pos]
        if self.lo <= ch <= self.hi:
            return Match(self, pos, 1)
        return MISMATCH

    def __str__(self) -> str:
        return f'[{self.lo}-{self.hi}]'


@dataclass(frozen=True, slots=True)
class AnyChar:
    """Matches any single character."""

    transparent: bool = False

    def match(self, parser: Parser, pos: int, bound: Clause | None = None) -> MatchResult:
        if pos >= len(parser.input):
            return MISMATCH
        return Match(self, pos, 1)

    def __str__(self) -> str:
        return '.'
