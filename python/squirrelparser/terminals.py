"""Terminal clause implementations for the Squirrel Parser."""

from __future__ import annotations
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import TYPE_CHECKING

from .match_result import Match, MISMATCH

if TYPE_CHECKING:
    from .clause import Clause
    from .match_result import MatchResult
    from .parser import Parser


class Terminal(ABC):
    """Base class for all terminal clause types."""

    transparent: bool

    @abstractmethod
    def match(self, parser: Parser, pos: int, bound: Clause | None = None) -> MatchResult:
        """Match this terminal against the input at the given position."""
        pass

    @abstractmethod
    def __str__(self) -> str:
        """Return a string representation of this terminal."""
        pass


@dataclass(frozen=True, slots=True)
class Str(Terminal):
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
class Char(Terminal):
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
class CharRange(Terminal):
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
class AnyChar(Terminal):
    """Matches any single character."""

    transparent: bool = False

    def match(self, parser: Parser, pos: int, bound: Clause | None = None) -> MatchResult:
        if pos >= len(parser.input):
            return MISMATCH
        return Match(self, pos, 1)

    def __str__(self) -> str:
        return '.'


@dataclass(frozen=True, slots=True)
class Nothing(Terminal):
    """Matches nothing - always succeeds without consuming any input."""

    transparent: bool = False

    def match(self, parser: Parser, pos: int, bound: Clause | None = None) -> MatchResult:
        return Match(self, pos, 0)

    def __str__(self) -> str:
        return '∅'
