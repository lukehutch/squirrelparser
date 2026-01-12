"""The squirrel parser with bounded error recovery."""

from __future__ import annotations
from typing import TYPE_CHECKING

from .clause import Clause
from .combinators import Ref
from .match_result import mismatch, SyntaxError, MatchResult
from .memo_entry import MemoEntry

if TYPE_CHECKING:
    pass


class Parser:
    """The squirrel parser with bounded error recovery."""

    __slots__ = ('rules', 'transparent_rules', 'top_rule_name', 'input', '_memo_table', 'memo_version', 'in_recovery_phase')

    def __init__(self, *, rules: dict[str, Clause], top_rule_name: str, input: str) -> None:
        self.rules: dict[str, Clause] = {}
        self.transparent_rules: set[str] = set()
        self.top_rule_name = top_rule_name
        self.input = input
        self._memo_table: dict[Clause, dict[int, MemoEntry]] = {}
        self.memo_version = [0] * (len(input) + 1)
        self.in_recovery_phase = False

        # Process rules: strip '~' prefix indicating a transparent rule
        for key, value in rules.items():
            if key.startswith('~'):
                rule_name = key[1:]
                self.rules[rule_name] = value
                self.transparent_rules.add(rule_name)
            else:
                self.rules[key] = value

    def match(self, clause: Clause, pos: int, *, bound: Clause | None = None) -> MatchResult:
        """Match a clause at a position, using memoization."""
        if pos > len(self.input):
            return mismatch

        # C5 (Ref Transparency): Don't memoize Ref independently
        if isinstance(clause, Ref):
            return clause.match(self, pos, bound=bound)

        clause_map = self._memo_table.get(clause)
        if clause_map is None:
            clause_map = {}
            self._memo_table[clause] = clause_map

        memo_entry = clause_map.get(pos)
        if memo_entry is None:
            memo_entry = MemoEntry()
            clause_map[pos] = memo_entry

        return memo_entry.match(self, clause, pos, bound)

    def match_rule(self, rule_name: str, pos: int) -> MatchResult:
        """Match a named rule at a position."""
        clause = self.rules.get(rule_name)
        if clause is None:
            raise ValueError(f'Rule "{rule_name}" not found')
        return self.match(clause, pos)

    def get_memo_entry(self, clause: Clause, pos: int) -> MemoEntry | None:
        """Get the MemoEntry for a clause at a position (if it exists)."""
        clause_map = self._memo_table.get(clause)
        return clause_map.get(pos) if clause_map is not None else None

    def probe(self, clause: Clause, pos: int) -> MatchResult:
        """Probe: Temporarily switch out of recovery mode to check if clause can match."""
        saved_phase = self.in_recovery_phase
        self.in_recovery_phase = False
        result = self.match(clause, pos)
        self.in_recovery_phase = saved_phase
        return result

    def enable_recovery(self) -> None:
        """Enable recovery mode (Phase 2)."""
        self.in_recovery_phase = True

    def can_match_nonzero_at(self, clause: Clause, pos: int) -> bool:
        """Check if clause can match non-zero characters at position."""
        result = self.probe(clause, pos)
        return not result.is_mismatch and result.len > 0

    def parse(self) -> ParseResult:
        """Parse input with two-phase error recovery."""
        # Phase 1: Discovery (try to parse without recovery from syntax errors)
        result = self.match_rule(self.top_rule_name, 0)
        has_syntax_errors = result.is_mismatch or result.pos != 0 or result.len != len(self.input)
        if has_syntax_errors:
            # Phase 2: Attempt to recover from syntax errors
            self.enable_recovery()
            result = self.match_rule(self.top_rule_name, 0)

        return ParseResult(
            input_str=self.input,
            root=result if not result.is_mismatch else SyntaxError(pos=0, length=len(self.input)),
            top_rule_name=self.top_rule_name,
            transparent_rules=self.transparent_rules,
            has_syntax_errors=has_syntax_errors,
            unmatched_input=(
                SyntaxError(pos=result.len, length=len(self.input) - result.len)
                if has_syntax_errors and result.len < len(self.input)
                else None
            ),
        )


# ------------------------------------------------------------------------------------------------------------------


class ParseResult:
    """The result of parsing the input."""

    __slots__ = ('input', 'root', 'top_rule_name', 'transparent_rules', 'has_syntax_errors', 'unmatched_input')

    def __init__(
        self,
        *,
        input_str: str,
        root: MatchResult,
        top_rule_name: str,
        transparent_rules: set[str],
        has_syntax_errors: bool,
        unmatched_input: SyntaxError | None,
    ) -> None:
        self.input = input_str
        self.root = root
        self.top_rule_name = top_rule_name
        self.transparent_rules = transparent_rules
        self.has_syntax_errors = has_syntax_errors
        self.unmatched_input = unmatched_input

    def get_syntax_errors(self) -> list[SyntaxError]:
        """Get the syntax errors from the parse."""
        if not self.has_syntax_errors:
            return []

        errors: list[SyntaxError] = []

        def collect_errors(result: MatchResult) -> None:
            if isinstance(result, SyntaxError):
                errors.append(result)
            else:
                for child in result.sub_clause_matches:
                    collect_errors(child)

        collect_errors(self.root)
        if self.unmatched_input is not None:
            errors.append(self.unmatched_input)
        return errors
