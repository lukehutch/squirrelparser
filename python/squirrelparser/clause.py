"""Base class for all grammar clauses."""

from __future__ import annotations
from abc import ABC, abstractmethod
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .match_result import MatchResult
    from .parser import Parser


class Clause(ABC):
    """Base class for all grammar clauses."""

    @abstractmethod
    def match(self, parser: Parser, pos: int, *, bound: Clause | None = None) -> MatchResult:
        """Match this clause at the given position."""
        ...

    @abstractmethod
    def check_rule_refs(self, grammar_map: dict[str, Clause]) -> None:
        """Check that all rule references in this clause are valid."""
        ...

    def __repr__(self) -> str:
        return self.__class__.__name__
