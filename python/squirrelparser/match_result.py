"""Match result types for the Squirrel Parser."""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Protocol

if TYPE_CHECKING:
    from .clause import Clause


class MatchResult(Protocol):
    """Protocol for match results."""

    @property
    def clause(self) -> Clause | None: ...

    @property
    def pos(self) -> int: ...

    @property
    def len(self) -> int: ...

    @property
    def is_complete(self) -> bool: ...

    @property
    def is_from_lr_context(self) -> bool | None: ...

    @property
    def sub_clause_matches(self) -> list[MatchResult]: ...

    @property
    def is_mismatch(self) -> bool: ...

    def with_lr_context(self) -> MatchResult: ...

    def to_pretty_string(self, input: str, indent: int = 0) -> str: ...


def _total_length(children: list[MatchResult]) -> int:
    """Calculate total length from first child's pos to last child's end."""
    if not children:
        return 0
    last = children[-1]
    return last.pos + last.len - children[0].pos


def _any_from_lr(children: list[MatchResult]) -> bool:
    """Check if any child is from LR context."""
    return any(r.is_from_lr_context for r in children)


@dataclass(frozen=True, slots=True)
class Match:
    """Successful match result."""

    clause: Clause | None
    pos: int
    len: int
    sub_clause_matches: list[MatchResult] = field(default_factory=list)
    is_complete: bool = True
    is_from_lr_context: bool | None = None

    def __post_init__(self) -> None:
        # Auto-compute from children if provided
        if self.sub_clause_matches:
            object.__setattr__(self, 'pos', self.sub_clause_matches[0].pos)
            object.__setattr__(self, 'len', _total_length(self.sub_clause_matches))
            
        # Auto-compute is_from_lr_context if not explicitly set
        if self.is_from_lr_context is None:
            computed = False
            if self.sub_clause_matches:
                computed = _any_from_lr(self.sub_clause_matches)
            object.__setattr__(self, 'is_from_lr_context', computed)
        # Else: keep the explicitly provided value (even if False)

    @property
    def is_mismatch(self) -> bool:
        return False

    def with_lr_context(self) -> MatchResult:
        if self.is_from_lr_context:
            return self
        return Match(
            self.clause,
            self.pos,
            self.len,
            self.sub_clause_matches,
            self.is_complete,
            True
        )

    def to_pretty_string(self, input: str, indent: int = 0) -> str:
        """Pretty print the match tree."""
        prefix = '  ' * indent
        clause_name = (
            getattr(self.clause, 'name', None)
            or (self.clause.__class__.__name__ if self.clause else 'Unknown')
        )

        result = f'{prefix}{clause_name}'

        if not self.sub_clause_matches:
            result += f': "{input[self.pos:self.pos + self.len]}"'

        result += '\n'

        for child in self.sub_clause_matches:
            result += child.to_pretty_string(input, indent + 1)

        return result


@dataclass(frozen=True, slots=True)
class Mismatch:
    """Mismatch result (sentinel with len=-1)."""

    is_from_lr_context: bool = False

    @property
    def clause(self) -> None:
        return None

    @property
    def pos(self) -> int:
        return -1

    @property
    def len(self) -> int:
        return -1

    @property
    def is_complete(self) -> bool:
        return True

    @property
    def sub_clause_matches(self) -> list[MatchResult]:
        return []

    @property
    def is_mismatch(self) -> bool:
        return True

    def with_lr_context(self) -> Mismatch:
        return LR_PENDING

    def to_pretty_string(self, input: str, indent: int = 0) -> str:
        """Pretty print the mismatch."""
        return f"{'  ' * indent}MISMATCH\n"


# Singleton instances
MISMATCH = Mismatch()
LR_PENDING = Mismatch(is_from_lr_context=True)


@dataclass(frozen=True, slots=True)
class SyntaxError:
    """Syntax error node: records skipped input or deleted grammar elements."""

    pos: int
    len: int
    skipped: str = ''
    is_deletion: bool = False

    @property
    def clause(self) -> None:
        return None

    @property
    def is_complete(self) -> bool:
        return True

    @property
    def is_from_lr_context(self) -> bool:
        return False

    @property
    def sub_clause_matches(self) -> list[MatchResult]:
        return []

    @property
    def is_mismatch(self) -> bool:
        return False

    def with_lr_context(self) -> SyntaxError:
        return self

    def __str__(self) -> str:
        if self.is_deletion:
            return f'DELETION@{self.pos}'
        return f'SKIP("{self.skipped}")@{self.pos}'

    def to_pretty_string(self, input: str, indent: int = 0) -> str:
        """Pretty print the syntax error."""
        return f"{'  ' * indent}{self.__str__()}\n"
