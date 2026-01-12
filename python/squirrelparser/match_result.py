"""Result of matching a clause at a position."""

from __future__ import annotations
from abc import ABC, abstractmethod
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .clause import Clause


def _total_length(children: list[MatchResult]) -> int:
    """Compute total length spanned by children."""
    if not children:
        return 0
    return children[-1].pos + children[-1].len - children[0].pos


def _any_from_lr(children: list[MatchResult]) -> bool:
    """Check if any child is from LR context."""
    return any(r.is_from_lr_context for r in children)


# ------------------------------------------------------------------------------------------------------------------


class MatchResult(ABC):
    """
    Result of matching a clause at a position.

    All match types (terminals, single child, multiple children) are unified.
    They differ only in |children|: terminals (0), single (1), multiple (n).
    """

    __slots__ = ('clause', 'pos', 'len', 'tot_descendant_errors', 'is_complete', 'is_from_lr_context')

    def __init__(
        self,
        clause: Clause | None,
        pos: int,
        length: int,
        *,
        is_complete: bool = True,
        is_from_lr_context: bool = False,
        tot_descendant_errors: int = 0,
    ) -> None:
        self.clause = clause
        self.pos = pos
        self.len = length
        self.is_complete = is_complete
        self.is_from_lr_context = is_from_lr_context
        self.tot_descendant_errors = tot_descendant_errors

    @property
    @abstractmethod
    def sub_clause_matches(self) -> list[MatchResult]:
        """Get child match results."""
        ...

    @property
    def is_mismatch(self) -> bool:
        """Check if this is a mismatch."""
        return False

    @abstractmethod
    def with_lr_context(self) -> MatchResult:
        """Create a copy with is_from_lr_context=True."""
        ...

    @abstractmethod
    def to_pretty_string(self, input_str: str, indent: int = 0) -> str:
        """Pretty print the match result."""
        ...


# ------------------------------------------------------------------------------------------------------------------


class Match(MatchResult):
    """
    A successful match (unified type for all match results).
    Terminals have empty children list, combinators have one or more children.
    """

    __slots__ = ('_sub_clause_matches', '_is_mismatch')

    def __init__(
        self,
        clause: Clause | None,
        pos: int,
        length: int,
        *,
        sub_clause_matches: list[MatchResult] | None = None,
        is_complete: bool = True,
        is_from_lr_context: bool | None = None,
        num_syntax_errors: int = 0,
        add_sub_clause_errors: bool = True,
    ) -> None:
        children = sub_clause_matches if sub_clause_matches is not None else []

        computed_pos = pos if not children else children[0].pos
        computed_len = length if not children else _total_length(children)
        computed_is_from_lr_context = (
            is_from_lr_context if is_from_lr_context is not None
            else (False if not children else _any_from_lr(children))
        )
        computed_tot_descendant_errors = (
            num_syntax_errors + sum(r.tot_descendant_errors for r in children)
            if add_sub_clause_errors
            else num_syntax_errors
        )

        super().__init__(
            clause,
            computed_pos,
            computed_len,
            is_complete=is_complete,
            is_from_lr_context=computed_is_from_lr_context,
            tot_descendant_errors=computed_tot_descendant_errors,
        )
        self._sub_clause_matches = children
        self._is_mismatch = pos == -1 and length == -1 and not children

    @property
    def sub_clause_matches(self) -> list[MatchResult]:
        return self._sub_clause_matches

    @property
    def is_mismatch(self) -> bool:
        return self._is_mismatch

    def with_lr_context(self) -> MatchResult:
        if self._is_mismatch:
            return lr_pending
        if self.is_from_lr_context:
            return self
        return Match(
            self.clause,
            self.pos,
            self.len,
            sub_clause_matches=self._sub_clause_matches,
            is_complete=self.is_complete,
            is_from_lr_context=True,
            num_syntax_errors=self.tot_descendant_errors,
            add_sub_clause_errors=False,
        )

    def to_pretty_string(self, input_str: str, indent: int = 0) -> str:
        from .combinators import Ref

        buffer: list[str] = []
        buffer.append('  ' * indent)
        if self._is_mismatch:
            buffer.append('MISMATCH\n')
            return ''.join(buffer)

        buffer.append(str(self.clause) if isinstance(self.clause, Ref) else self.clause.__class__.__name__ if self.clause else 'None')
        if not self._sub_clause_matches:
            buffer.append(f': "{input_str[self.pos:self.pos + self.len]}"')
        buffer.append('\n')

        for child in self._sub_clause_matches:
            buffer.append(child.to_pretty_string(input_str, indent + 1))

        return ''.join(buffer)


# ------------------------------------------------------------------------------------------------------------------


class SyntaxError(Match):
    """
    A syntax error node: records skipped input or deleted grammar elements.
    if len == 0, then this was a deletion of a grammar element, and clause is the deleted clause.
    if len > 0, then this was an insertion of skipped input.
    """

    # The AST/CST node label for syntax errors.
    node_label: str = '<SyntaxError>'

    def __init__(self, *, pos: int, length: int, deleted_clause: Clause | None = None) -> None:
        super().__init__(
            deleted_clause,
            pos,
            length,
            is_complete=True,
            num_syntax_errors=1,
        )

    def with_lr_context(self) -> MatchResult:
        return self  # SyntaxErrors don't need LR context

    def __repr__(self) -> str:
        # If len == 0, this is a deletion of a grammar element;
        # if len > 0, this is an insertion of skipped input.
        if self.len == 0:
            clause_name = self.clause.__class__.__name__ if self.clause else 'unknown'
            return f'Missing grammar element {clause_name} at pos {self.pos}'
        return f'{self.len} characters of unexpected input at pos {self.pos}'

    def to_pretty_string(self, input_str: str, indent: int = 0) -> str:
        return f"{'  ' * indent}<SyntaxError>: {self!r}\n"


# ------------------------------------------------------------------------------------------------------------------


# Singleton mismatch instances
mismatch: MatchResult = Match(None, -1, -1)

# Special mismatch indicating LR cycle in progress.
lr_pending: MatchResult = Match(None, -1, -1, is_from_lr_context=True)
