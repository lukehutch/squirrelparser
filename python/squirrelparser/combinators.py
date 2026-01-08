"""Combinator clause implementations for the Squirrel Parser."""

from __future__ import annotations
from dataclasses import dataclass
from typing import TYPE_CHECKING

from .match_result import Match, SyntaxError, MISMATCH

if TYPE_CHECKING:
    from .clause import Clause
    from .match_result import MatchResult
    from .parser import Parser


def _all_complete(children: list[MatchResult]) -> bool:
    """Check if all children are complete."""
    return all(r.is_mismatch or r.is_complete for r in children)


def count_errors(result: MatchResult | None) -> int:
    """Count total syntax errors in a parse tree."""
    if result is None or result.is_mismatch:
        return 0
    count = 1 if isinstance(result, SyntaxError) else 0
    for child in result.sub_clause_matches:
        count += count_errors(child)
    return count


def get_syntax_errors(result: MatchResult, input: str) -> list[SyntaxError]:
    """Get all syntax errors from parse tree.

    The parse tree is expected to span the entire input (invariant from Parser.parse()).
    All syntax errors are already embedded in the tree as SyntaxError nodes.
    """
    syntax_errors: list[SyntaxError] = []

    def collect(r: MatchResult) -> None:
        """Recursively collect syntax errors."""
        if r.is_mismatch:
            return
        if isinstance(r, SyntaxError):
            syntax_errors.append(r)
        for child in r.sub_clause_matches:
            collect(child)

    collect(result)
    return syntax_errors


@dataclass(frozen=True, slots=True)
class Seq:
    """Sequence: matches all sub-clauses in order, with error recovery."""

    sub_clauses: tuple[Clause, ...]
    transparent: bool = False

    def __init__(self, *clauses: Clause, transparent: bool = False):
        object.__setattr__(self, 'sub_clauses', clauses)
        object.__setattr__(self, 'transparent', transparent)

    def match(self, parser: Parser, pos: int, bound: Clause | None = None) -> MatchResult:
        children: list[MatchResult] = []
        curr = pos
        i = 0

        while i < len(self.sub_clauses):
            clause = self.sub_clauses[i]
            next_clause = self.sub_clauses[i + 1] if i + 1 < len(self.sub_clauses) else None
            effective_bound = next_clause if (parser.in_recovery_phase and next_clause is not None) else bound
            result = parser.match(clause, curr, effective_bound)

            if result.is_mismatch:
                if parser.in_recovery_phase and not result.is_from_lr_context:
                    recovery = self._recover(parser, curr, i)
                    if recovery is not None:
                        input_skip, grammar_skip, probe = recovery

                        if input_skip > 0:
                            children.append(SyntaxError(
                                pos=curr,
                                len=input_skip,
                                skipped=parser.input[curr:curr + input_skip],
                            ))

                        for _ in range(grammar_skip):
                            children.append(SyntaxError(
                                pos=curr + input_skip,
                                len=0,
                                is_deletion=True,
                            ))

                        if probe is None:
                            curr += input_skip
                            break

                        children.append(probe)
                        curr += input_skip + probe.len
                        i += grammar_skip + 1
                        continue
                return MISMATCH

            children.append(result)
            curr += result.len
            i += 1

        if not children:
            return Match(self, pos, 0)

        return Match(self, pos, curr - pos, children, _all_complete(children))

    def _recover(self, parser: Parser, curr: int, i: int) -> tuple[int, int, MatchResult | None] | None:
        """Attempt to recover from a mismatch."""
        from .terminals import Str

        max_scan = len(parser.input) - curr + 1
        max_grammar = len(self.sub_clauses) - i

        for input_skip in range(max_scan):
            probe_pos = curr + input_skip

            if probe_pos >= len(parser.input):
                if input_skip == 0:
                    return (input_skip, max_grammar, None)
                continue

            for grammar_skip in range(max_grammar):
                if grammar_skip == 0 and input_skip == 0:
                    continue
                if grammar_skip > 0:
                    continue

                clause_idx = i + grammar_skip
                clause = self.sub_clauses[clause_idx]

                failed_clause = self.sub_clauses[i]
                if (isinstance(failed_clause, Str) and
                    len(failed_clause.text) == 1 and
                    input_skip > 1):
                    if clause_idx + 1 < len(self.sub_clauses):
                        next_clause = self.sub_clauses[clause_idx + 1]
                        if isinstance(next_clause, Str):
                            skipped = parser.input[curr:curr + input_skip]
                            if next_clause.text in skipped:
                                continue

                probe = parser.probe(clause, probe_pos)

                if not probe.is_mismatch:
                    if isinstance(clause, Str) and input_skip > len(clause.text):
                        if len(clause.text) > 1:
                            continue
                        skipped = parser.input[curr:curr + input_skip]
                        if clause.text in skipped:
                            continue

                    return (input_skip, grammar_skip, probe)

        return None

    def __str__(self) -> str:
        return f"({' '.join(str(c) for c in self.sub_clauses)})"


@dataclass(frozen=True, slots=True)
class First:
    """Ordered choice: matches the first successful sub-clause."""

    sub_clauses: tuple[Clause, ...]
    transparent: bool = False

    def __init__(self, *clauses: Clause, transparent: bool = False):
        object.__setattr__(self, 'sub_clauses', clauses)
        object.__setattr__(self, 'transparent', transparent)

    def match(self, parser: Parser, pos: int, bound: Clause | None = None) -> MatchResult:
        for i, clause in enumerate(self.sub_clauses):
            result = parser.match(clause, pos, bound)
            if not result.is_mismatch:
                if parser.in_recovery_phase and i == 0 and count_errors(result) > 0:
                    best_result = result
                    best_len = result.len
                    best_errors = count_errors(result)

                    for j in range(1, len(self.sub_clauses)):
                        alt_result = parser.match(self.sub_clauses[j], pos, bound)
                        if not alt_result.is_mismatch:
                            alt_len = alt_result.len
                            alt_errors = count_errors(alt_result)

                            best_error_rate = best_errors / best_len if best_len > 0 else 0.0
                            alt_error_rate = alt_errors / alt_len if alt_len > 0 else 0.0
                            error_rate_threshold = 0.5

                            should_switch = False

                            if best_error_rate >= error_rate_threshold and alt_error_rate < error_rate_threshold:
                                should_switch = True
                            elif alt_len > best_len:
                                should_switch = True
                            elif alt_len == best_len and alt_errors < best_errors:
                                should_switch = True

                            if should_switch:
                                best_result = alt_result
                                best_len = alt_len
                                best_errors = alt_errors

                            if alt_errors == 0 and alt_len >= best_len:
                                break

                    return Match(self, pos, best_result.len, [best_result], best_result.is_complete)

                return Match(self, pos, result.len, [result], result.is_complete)
        return MISMATCH

    def __str__(self) -> str:
        return f"({' / '.join(str(c) for c in self.sub_clauses)})"


class _RepetitionMixin:
    """Mixin providing repetition match logic for OneOrMore and ZeroOrMore."""

    sub_clause: Clause
    transparent: bool
    _require_one: bool

    def match(self, parser: Parser, pos: int, bound: Clause | None = None) -> MatchResult:
        children: list[MatchResult] = []
        curr = pos
        incomplete = False
        has_recovered = False

        while curr <= len(parser.input):
            if parser.in_recovery_phase and bound is not None:
                if parser.can_match_nonzero_at(bound, curr):
                    break

            result = parser.match(self.sub_clause, curr)

            if result.is_mismatch:
                if not parser.in_recovery_phase and curr < len(parser.input):
                    incomplete = True

                if parser.in_recovery_phase:
                    recovery = self._recover(parser, curr, has_recovered)
                    if recovery is not None:
                        skip, probe = recovery
                        children.append(SyntaxError(
                            pos=curr,
                            len=skip,
                            skipped=parser.input[curr:curr + skip],
                        ))
                        has_recovered = True
                        if probe is not None:
                            children.append(probe)
                            curr += skip + probe.len
                            continue
                        else:
                            curr += skip
                            break
                break

            if result.len == 0:
                break
            children.append(result)
            curr += result.len

        if self._require_one and not children:
            return MISMATCH

        if not children:
            return Match(self, pos, 0, is_complete=not incomplete)

        return Match(self, pos, curr - pos, children, not incomplete and _all_complete(children))

    def _recover(self, parser: Parser, curr: int, has_recovered: bool) -> tuple[int, MatchResult | None] | None:
        """Attempt recovery within repetition."""
        for skip in range(1, len(parser.input) - curr + 1):
            probe = parser.probe(self.sub_clause, curr + skip)
            if not probe.is_mismatch:
                return (skip, probe)

        # If we've already recovered from previous errors and we're at or near
        # end of input, try to skip to end of input as a recovery
        if has_recovered and curr < len(parser.input):
            skip_to_end = len(parser.input) - curr
            return (skip_to_end, None)

        return None


@dataclass(frozen=True, slots=True)
class OneOrMore(_RepetitionMixin):
    """One or more repetitions."""

    sub_clause: Clause
    transparent: bool = False
    _require_one: bool = True

    def __init__(self, sub_clause: Clause, *, transparent: bool = False):
        object.__setattr__(self, 'sub_clause', sub_clause)
        object.__setattr__(self, 'transparent', transparent)
        object.__setattr__(self, '_require_one', True)

    def __str__(self) -> str:
        return f'{self.sub_clause}+'


@dataclass(frozen=True, slots=True)
class ZeroOrMore(_RepetitionMixin):
    """Zero or more repetitions."""

    sub_clause: Clause
    transparent: bool = False
    _require_one: bool = False

    def __init__(self, sub_clause: Clause, *, transparent: bool = False):
        object.__setattr__(self, 'sub_clause', sub_clause)
        object.__setattr__(self, 'transparent', transparent)
        object.__setattr__(self, '_require_one', False)

    def __str__(self) -> str:
        return f'{self.sub_clause}*'


@dataclass(frozen=True, slots=True)
class Optional:
    """Optional: matches zero or one instance."""

    sub_clause: Clause
    transparent: bool = False

    def match(self, parser: Parser, pos: int, bound: Clause | None = None) -> MatchResult:
        result = parser.match(self.sub_clause, pos, bound)

        if result.is_mismatch:
            incomplete = not parser.in_recovery_phase and pos < len(parser.input)
            return Match(self, pos, 0, is_complete=not incomplete)

        return Match(self, pos, result.len, [result], result.is_complete)

    def __str__(self) -> str:
        return f'{self.sub_clause}?'


@dataclass(frozen=True, slots=True)
class Ref:
    """Reference to a named rule."""

    rule_name: str
    transparent: bool = False

    def match(self, parser: Parser, pos: int, bound: Clause | None = None) -> MatchResult:
        clause = parser.rules.get(self.rule_name)
        if clause is None:
            raise ValueError(f'Rule "{self.rule_name}" not found')
        result = parser.match(clause, pos, bound)

        if result.is_mismatch:
            return result

        return Match(self, pos, result.len, [result], result.is_complete)

    def __str__(self) -> str:
        return self.rule_name


@dataclass(frozen=True, slots=True)
class NotFollowedBy:
    """Negative lookahead: succeeds if sub-clause fails, consumes nothing."""

    sub_clause: Clause
    transparent: bool = False

    def match(self, parser: Parser, pos: int, bound: Clause | None = None) -> MatchResult:
        result = parser.match(self.sub_clause, pos, bound)
        return Match(self, pos, 0) if result.is_mismatch else MISMATCH

    def __str__(self) -> str:
        return f'!{self.sub_clause}'


@dataclass(frozen=True, slots=True)
class FollowedBy:
    """Positive lookahead: succeeds if sub-clause succeeds, consumes nothing."""

    sub_clause: Clause
    transparent: bool = False

    def match(self, parser: Parser, pos: int, bound: Clause | None = None) -> MatchResult:
        result = parser.match(self.sub_clause, pos, bound)
        return MISMATCH if result.is_mismatch else Match(self, pos, 0)

    def __str__(self) -> str:
        return f'&{self.sub_clause}'
