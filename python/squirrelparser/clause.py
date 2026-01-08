"""Base clause protocol for the Squirrel Parser."""

from __future__ import annotations
from typing import Protocol, TYPE_CHECKING

if TYPE_CHECKING:
    from .match_result import MatchResult
    from .parser import Parser


class Clause(Protocol):
    """Protocol for all grammar clauses."""

    @property
    def transparent(self) -> bool:
        """
        If True, this clause is transparent in the AST - its children are promoted
        to the parent rather than creating a node for this clause.
        """
        ...

    def match(self, parser: Parser, pos: int, bound: Clause | None = None) -> MatchResult:
        """
        Match this clause at the given position in the parser's input.

        Args:
            parser: The parser instance
            pos: The position to match at
            bound: Optional boundary clause for recovery

        Returns:
            Match result (Match, Mismatch, or SyntaxError)
        """
        ...
