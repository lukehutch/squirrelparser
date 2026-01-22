"""Combinator clauses for the parser."""

from __future__ import annotations
from abc import ABC
from typing import TYPE_CHECKING

from .clause import Clause
from .match_result import Match, SyntaxError, mismatch, MatchResult
from . import parser_stats as stats_module

if TYPE_CHECKING:
    from .parser import Parser


def _all_complete(children: list[MatchResult]) -> bool:
    """Check if all children are complete."""
    return all(c.is_mismatch or c.is_complete for c in children)


# ------------------------------------------------------------------------------------------------------------------


class HasOneSubClause(Clause, ABC):
    """Base class for clauses with one sub-clause."""

    __slots__ = ('sub_clause',)

    def __init__(self, sub_clause: Clause) -> None:
        self.sub_clause = sub_clause

    def check_rule_refs(self, grammar_map: dict[str, Clause]) -> None:
        self.sub_clause.check_rule_refs(grammar_map)


# ------------------------------------------------------------------------------------------------------------------


class HasMultipleSubClauses(Clause, ABC):
    """Base class for clauses with multiple sub-clauses."""

    __slots__ = ('sub_clauses',)

    def __init__(self, sub_clauses: list[Clause]) -> None:
        self.sub_clauses = sub_clauses

    def check_rule_refs(self, grammar_map: dict[str, Clause]) -> None:
        for clause in self.sub_clauses:
            clause.check_rule_refs(grammar_map)


# ------------------------------------------------------------------------------------------------------------------


class Seq(HasMultipleSubClauses):
    """Sequence: matches all sub-clauses in order, with error recovery."""

    def _find_meaningful_bound(self, start_idx: int, parser: Parser) -> Clause | None:
        """
        Find the first meaningful bound among remaining siblings.
        Skips over transparent rules (marked with ~) since they don't produce AST nodes
        and shouldn't be used as structural boundaries.
        """
        for j in range(start_idx, len(self.sub_clauses)):
            clause = self.sub_clauses[j]

            # Check if this clause is a Ref to a transparent rule
            if isinstance(clause, Ref) and clause.rule_name in parser.transparent_rules:
                continue

            # Found a non-transparent clause - use as bound
            return clause
        return None

    def match(self, parser: Parser, pos: int, *, bound: Clause | None = None) -> MatchResult:

        children: list[MatchResult] = []
        curr = pos
        i = 0

        while i < len(self.sub_clauses):
            clause = self.sub_clauses[i]
            # Find meaningful bound by looking past transparent rules
            sibling_bound = self._find_meaningful_bound(i + 1, parser)
            effective_bound = sibling_bound if (parser.in_recovery_phase and sibling_bound is not None) else bound
            result = parser.match(clause, curr, bound=effective_bound)

            if result.is_mismatch:
                if parser.in_recovery_phase and not result.is_from_lr_context:
                    recovery = self._recover(parser, curr, i)
                    if recovery is not None:
                        if stats_module.parser_stats is not None:
                            stats_module.parser_stats.record_recovery()
                        input_skip, grammar_skip, probe = recovery

                        if input_skip > 0:
                            children.append(SyntaxError(pos=curr, length=input_skip))

                        for j in range(grammar_skip):
                            children.append(SyntaxError(pos=curr + input_skip, length=0, deleted_clause=self.sub_clauses[i + j]))

                        if probe is None:
                            curr += input_skip
                            break

                        children.append(probe)
                        curr += input_skip + probe.len
                        i += grammar_skip + 1
                        continue
                return mismatch

            children.append(result)
            curr += result.len
            i += 1

        if not children:
            return Match(self, pos, 0)

        return Match(self, 0, 0, sub_clause_matches=children, is_complete=_all_complete(children))

    def _recover(self, parser: Parser, curr: int, i: int) -> tuple[int, int, MatchResult | None] | None:
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
                if isinstance(failed_clause, Str) and len(failed_clause.text) == 1 and input_skip > 1:
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

    def __repr__(self) -> str:
        return f"({' '.join(repr(c) for c in self.sub_clauses)})"


# ------------------------------------------------------------------------------------------------------------------


class First(HasMultipleSubClauses):
    """Ordered choice: matches the first successful sub-clause."""

    def match(self, parser: Parser, pos: int, *, bound: Clause | None = None) -> MatchResult:
        for i, sub_clause in enumerate(self.sub_clauses):
            result = parser.match(sub_clause, pos, bound=bound)
            if not result.is_mismatch:
                if parser.in_recovery_phase and i == 0 and result.tot_descendant_errors > 0:
                    best_result = result
                    best_len = result.len
                    best_errors = result.tot_descendant_errors

                    for j in range(1, len(self.sub_clauses)):
                        alt_result = parser.match(self.sub_clauses[j], pos, bound=bound)
                        if not alt_result.is_mismatch:
                            alt_len = alt_result.len
                            alt_errors = alt_result.tot_descendant_errors

                            best_error_rate = best_errors / best_len if best_len > 0 else 0.0
                            alt_error_rate = alt_errors / alt_len if alt_len > 0 else 0.0
                            error_rate_threshold = 0.5

                            if ((best_error_rate >= error_rate_threshold and alt_error_rate < error_rate_threshold) or
                                alt_len > best_len or
                                (alt_len == best_len and alt_errors < best_errors)):
                                best_result = alt_result
                                best_len = alt_len
                                best_errors = alt_errors
                            if alt_errors == 0 and alt_len >= best_len:
                                break

                    return Match(self, 0, 0, sub_clause_matches=[best_result], is_complete=best_result.is_complete)
                return Match(self, 0, 0, sub_clause_matches=[result], is_complete=result.is_complete)
        return mismatch

    def __repr__(self) -> str:
        return f"({' / '.join(repr(c) for c in self.sub_clauses)})"


# ------------------------------------------------------------------------------------------------------------------


class Repetition(HasOneSubClause):
    """Base class for repetition (OneOrMore, ZeroOrMore)."""

    __slots__ = ('_require_one',)

    def __init__(self, sub_clause: Clause, *, require_one: bool) -> None:
        super().__init__(sub_clause)
        self._require_one = require_one

    def match(self, parser: Parser, pos: int, *, bound: Clause | None = None) -> MatchResult:
        children: list[MatchResult] = []
        curr = pos
        incomplete = False

        while curr <= len(parser.input):
            if parser.in_recovery_phase and bound is not None:
                if parser.can_match_nonzero_at(bound, curr):
                    break

            result = parser.match(self.sub_clause, curr)
            if result.is_mismatch:
                if not parser.in_recovery_phase and curr < len(parser.input):
                    incomplete = True

                if parser.in_recovery_phase:
                    # Only pass has_valid_match=True if we have at least one non-error child
                    has_valid_match = any(not isinstance(c, SyntaxError) for c in children)
                    recovery = self._recover(parser, curr, has_valid_match, bound)
                    if recovery is not None:
                        if stats_module.parser_stats is not None:
                            stats_module.parser_stats.record_recovery()
                        skip, probe = recovery
                        children.append(SyntaxError(pos=curr, length=skip))
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
            return mismatch
        if not children:
            return Match(self, pos, 0, is_complete=not incomplete)
        return Match(self, 0, 0, sub_clause_matches=children, is_complete=not incomplete and _all_complete(children))

    def _recover(self, parser: Parser, curr: int, has_valid_match: bool, bound: Clause | None) -> tuple[int, MatchResult | None] | None:
        """
        Attempt recovery within repetition.

        Key principle: Repetitions only do recovery for COMPLEX sub_clauses (Seq, First, Ref).
        For character-level terminals (CharSet, Char, AnyChar), the repetition should NOT
        try to extend itself by skipping over errors. Instead, return what we have and
        let the parent Seq handle errors with better structural context.

        has_valid_match: indicates if we've already matched at least one valid element.
        bound: the next sibling clause that must not be skipped over.
        """
        from .terminals import CharSet, Char, AnyChar

        # For character-level terminals, don't do repetition recovery
        if isinstance(self.sub_clause, (CharSet, Char, AnyChar)):
            return None

        # Scan for more matches
        for skip in range(1, len(parser.input) - curr + 1):
            probe_pos = curr + skip

            # Don't skip past the bound - let parent Seq handle recovery there
            if bound is not None and parser.can_match_nonzero_at(bound, probe_pos):
                break

            # Use match to allow internal recovery within complex sub_clauses
            probe = parser.match(self.sub_clause, probe_pos)
            if not probe.is_mismatch and probe.len > 0:
                return (skip, probe)

        # No more matches found.
        # Only skip remaining as error if we already have valid matches
        # (otherwise OneOrMore would incorrectly succeed with just errors).
        # But don't skip past the bound!
        if has_valid_match and curr < len(parser.input):
            skip_to_end = len(parser.input) - curr
            # Check if bound matches anywhere before end of input
            if bound is not None:
                for skip in range(1, skip_to_end + 1):
                    if parser.can_match_nonzero_at(bound, curr + skip):
                        # Bound matches at this position - only skip up to here
                        if skip > 0:
                            return (skip, None)
                        return None  # Can't skip anything without hitting bound
            return (skip_to_end, None)
        return None


# ------------------------------------------------------------------------------------------------------------------


class OneOrMore(Repetition):
    """One or more repetitions."""

    def __init__(self, sub_clause: Clause) -> None:
        super().__init__(sub_clause, require_one=True)

    def __repr__(self) -> str:
        return f"{self.sub_clause!r}+"


# ------------------------------------------------------------------------------------------------------------------


class ZeroOrMore(Repetition):
    """Zero or more repetitions."""

    def __init__(self, sub_clause: Clause) -> None:
        super().__init__(sub_clause, require_one=False)

    def __repr__(self) -> str:
        return f"{self.sub_clause!r}*"


# ------------------------------------------------------------------------------------------------------------------


class Optional(HasOneSubClause):
    """Optional: matches zero or one instance."""

    def match(self, parser: Parser, pos: int, *, bound: Clause | None = None) -> MatchResult:
        result = parser.match(self.sub_clause, pos, bound=bound)

        if result.is_mismatch:
            incomplete = not parser.in_recovery_phase and pos < len(parser.input)
            return Match(self, pos, 0, is_complete=not incomplete)

        return Match(self, 0, 0, sub_clause_matches=[result], is_complete=result.is_complete)

    def __repr__(self) -> str:
        return f"{self.sub_clause!r}?"


# ------------------------------------------------------------------------------------------------------------------


class Ref(Clause):
    """Reference to a named rule."""

    __slots__ = ('rule_name',)

    def __init__(self, rule_name: str) -> None:
        self.rule_name = rule_name

    def match(self, parser: Parser, pos: int, *, bound: Clause | None = None) -> MatchResult:
        clause = parser.rules.get(self.rule_name)
        if clause is None:
            raise ValueError(f'Rule "{self.rule_name}" not found')
        result = parser.match(clause, pos, bound=bound)
        if result.is_mismatch:
            return result
        return Match(self, 0, 0, sub_clause_matches=[result], is_complete=result.is_complete)

    def check_rule_refs(self, grammar_map: dict[str, Clause]) -> None:
        if self.rule_name not in grammar_map and f'~{self.rule_name}' not in grammar_map:
            raise ValueError(f'Rule "{self.rule_name}" not found in grammar')

    def __repr__(self) -> str:
        return self.rule_name


# ------------------------------------------------------------------------------------------------------------------


class NotFollowedBy(HasOneSubClause):
    """Negative lookahead: succeeds if sub-clause fails, consumes nothing."""

    def match(self, parser: Parser, pos: int, *, bound: Clause | None = None) -> MatchResult:
        result = parser.match(self.sub_clause, pos, bound=bound)
        return Match(self, pos, 0) if result.is_mismatch else mismatch

    def __repr__(self) -> str:
        return f"!{self.sub_clause!r}"


# ------------------------------------------------------------------------------------------------------------------


class FollowedBy(HasOneSubClause):
    """Positive lookahead: succeeds if sub-clause succeeds, consumes nothing."""

    def match(self, parser: Parser, pos: int, *, bound: Clause | None = None) -> MatchResult:
        result = parser.match(self.sub_clause, pos, bound=bound)
        return mismatch if result.is_mismatch else Match(self, pos, 0)

    def __repr__(self) -> str:
        return f"&{self.sub_clause!r}"
