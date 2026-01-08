"""Parser class with packrat memoization and left-recursion handling."""

from __future__ import annotations
from typing import TYPE_CHECKING
from collections.abc import Mapping

from .match_result import MISMATCH, LR_PENDING, SyntaxError, Match
from .ast_node import ASTNode, build_ast

if TYPE_CHECKING:
    from .clause import Clause
    from .match_result import MatchResult


class MemoEntry:
    """A memo table entry for a (clause, position) pair.

    SATISFIES:
      - A1 (Packrat Invariant): Memoization ensures each (clause, pos) evaluated once per phase
      - A4 (LR Fixed Point): Tracks in_rec_path/found_left_rec for cycle detection and expansion
      - C7 (Phase Isolation): cached_in_recovery_phase prevents cross-phase pollution
    """

    __slots__ = ('result', 'in_rec_path', 'found_left_rec', 'memo_version', 'cached_in_recovery_phase')

    def __init__(self) -> None:
        self.result: MatchResult | None = None
        self.in_rec_path = False
        self.found_left_rec = False
        self.memo_version = 0
        self.cached_in_recovery_phase = False

    def match(self, parser: Parser, clause: Clause, pos: int, bound: Clause | None) -> MatchResult:
        """Match a clause at a position, handling left recursion and caching."""
        # Cache validation (A1 - Packrat Invariant, C7 - Phase Isolation)
        if self.result is not None and self.memo_version == parser.memo_version[pos]:
            phase_matches = self.cached_in_recovery_phase == parser.in_recovery_phase

            # Special case: Top-level complete results that didn't reach EOF
            if (not self.result.is_mismatch and
                self.result.is_complete and
                pos == 0 and
                self.result.pos + self.result.len < len(parser.input) and
                not phase_matches):
                # Phase 1 result didn't reach EOF; retry in Phase 2
                pass
            elif (not self.result.is_mismatch and self.result.is_complete and not self.found_left_rec) or phase_matches:
                return self.result  # Cache hit

        # Left recursion cycle detection
        if self.in_rec_path:
            if self.result is None:
                self.found_left_rec = True
                self.result = MISMATCH
            if self.result.is_mismatch:
                return LR_PENDING
            return self.result

        self.in_rec_path = True

        # Clear stale results before expansion loop
        if (self.result is not None and
            (self.memo_version != parser.memo_version[pos] or
             (self.found_left_rec and self.cached_in_recovery_phase != parser.in_recovery_phase))):
            self.result = None

        # Left recursion expansion loop
        while True:
            new_result = clause.match(parser, pos, bound)

            if self.result is not None and new_result.len <= self.result.len:
                break  # No progress - fixed point reached

            self.result = new_result

            if not self.found_left_rec:
                break  # No left recursion - done in one iteration

            parser.memo_version[pos] += 1
            self.memo_version = parser.memo_version[pos]

        # Update cache metadata
        self.in_rec_path = False
        self.memo_version = parser.memo_version[pos]
        self.cached_in_recovery_phase = parser.in_recovery_phase

        # Mark LR results
        if self.found_left_rec and not self.result.is_mismatch and not self.result.is_from_lr_context:
            self.result = self.result.with_lr_context()

        return self.result


class Parser:
    """The squirrel parser with bounded error recovery."""

    def __init__(self, rules: Mapping[str, Clause], input_str: str):
        self.rules = rules
        self.input = input_str
        self._memo_table: dict[int, dict[int, MemoEntry]] = {}
        self.memo_version = [0] * (len(input_str) + 1)
        self.in_recovery_phase = False

    def match(self, clause: Clause, pos: int, bound: Clause | None = None) -> MatchResult:
        """Match a clause at a position, using memoization."""
        if pos > len(self.input):
            return MISMATCH

        # C5 (Ref Transparency): Don't memoize Ref independently
        from .combinators import Ref
        if isinstance(clause, Ref):
            return clause.match(self, pos, bound)

        # Use object id as key for memoization
        key = id(clause)

        if key not in self._memo_table:
            self._memo_table[key] = {}

        pos_map = self._memo_table[key]

        if pos not in pos_map:
            pos_map[pos] = MemoEntry()

        entry = pos_map[pos]
        return entry.match(self, clause, pos, bound)

    def match_rule(self, rule_name: str, pos: int) -> MatchResult:
        """Match a named rule at a position."""
        clause = self.rules.get(rule_name)
        if clause is None:
            raise ValueError(f'Rule "{rule_name}" not found')
        return self.match(clause, pos)

    def get_memo_entry(self, clause: Clause, pos: int) -> MemoEntry | None:
        """Get the MemoEntry for a clause at a position (if it exists)."""
        key = id(clause)
        return self._memo_table.get(key, {}).get(pos)

    def probe(self, clause: Clause, pos: int) -> MatchResult:
        """Probe: Temporarily switch to Phase 1 to check if clause can match."""
        saved_phase = self.in_recovery_phase
        self.in_recovery_phase = False
        result = self.match(clause, pos)
        self.in_recovery_phase = saved_phase
        return result

    def can_match_nonzero_at(self, clause: Clause, pos: int) -> bool:
        """Check if clause can match non-zero characters at position."""
        result = self.probe(clause, pos)
        return not result.is_mismatch and result.len > 0

    def enable_recovery(self) -> None:
        """Enable recovery mode (Phase 2)."""
        self.in_recovery_phase = True

    def _ensure_spans_input(self, result: MatchResult) -> MatchResult:
        """Ensure result spans entire input (parse tree spanning invariant).

        - Total failure: return SyntaxError spanning all input
        - Partial match: wrap with trailing SyntaxError
        - Complete match: return as-is
        """
        if result.is_mismatch:
            # Total failure: entire input is an error
            return SyntaxError(0, len(self.input), self.input)

        if result.len == len(self.input):
            # Already spans entire input
            return result

        # Partial match: wrap with trailing SyntaxError
        trailing = SyntaxError(
            result.len,
            len(self.input) - result.len,
            self.input[result.len:]
        )

        return Match(result.clause, 0, len(self.input), [result, trailing], False)

    def parse(self, top_rule_name: str) -> tuple[MatchResult, bool]:
        """Parse input with two-phase error recovery.

        Returns (result, usedRecovery) where:
          - result = MatchResult spanning entire input (never None)
          - usedRecovery = True if Phase 2 was needed
          - result is SyntaxError if parse failed completely
        """
        # Phase 1: Discovery
        result = self.match_rule(top_rule_name, 0)
        if not result.is_mismatch and result.len == len(self.input):
            return (result, False)

        # Phase 2: Recovery
        self.enable_recovery()
        result = self.match_rule(top_rule_name, 0)

        # Ensure result spans entire input
        result = self._ensure_spans_input(result)
        return (result, True)

    def parse_to_ast(self, top_rule_name: str) -> tuple[ASTNode, bool]:
        """Parse input and return an AST instead of a parse tree.

        Returns (ast, usedRecovery) where:
          - ast = ASTNode spanning entire input (never None)
          - usedRecovery = True if Phase 2 was needed
          - For total failures (SyntaxError at top level), wraps it in a synthetic node
        """
        parse_tree, used_recovery = self.parse(top_rule_name)

        # Result always spans input now, but may be total failure (SyntaxError)
        if isinstance(parse_tree, SyntaxError):
            # Total failure: create synthetic error node
            error_ast = ASTNode(
                label=top_rule_name,
                pos=parse_tree.pos,
                len=parse_tree.len,
                children=[],
                _input=self.input,
            )
            return (error_ast, used_recovery)

        # If the parse tree top-level is not a Ref (e.g., when matching the Grammar rule directly),
        # create a synthetic root AST node with the rule name
        ast = build_ast(parse_tree, self.input, top_rule_name)
        if ast is None:
            # Fallback empty AST node (shouldn't happen since build_ast with top_rule should always succeed)
            ast = ASTNode(
                label=top_rule_name,
                pos=parse_tree.pos,
                len=parse_tree.len,
                children=[],
                _input=self.input,
            )

        return (ast, used_recovery)
