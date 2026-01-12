"""A memo table entry for a (clause, position) pair."""

from __future__ import annotations
from typing import TYPE_CHECKING

from .match_result import MatchResult, mismatch, lr_pending
from . import parser_stats as stats_module

if TYPE_CHECKING:
    from .clause import Clause
    from .parser import Parser


class MemoEntry:
    """
    A memo table entry for a (clause, position) pair.

    SATISFIES:
      - A1 (Packrat Invariant): Memoization ensures each (clause, pos) evaluated once per phase
      - A4 (LR Fixed Point): Tracks in_rec_path/found_left_rec for cycle detection and expansion
      - C7 (Phase Isolation): cached_in_recovery_phase prevents cross-phase pollution
    """

    __slots__ = ('result', 'in_rec_path', 'found_left_rec', 'memo_version', 'cached_in_recovery_phase')

    def __init__(self) -> None:
        self.result: MatchResult | None = None
        self.in_rec_path: bool = False       # Currently on call stack (for LR cycle detection)
        self.found_left_rec: bool = False    # Left recursion detected (triggers expansion)
        self.memo_version: int = 0           # Version tag for LR seed invalidation
        # CONSTRAINT C7 (Phase Isolation): Tracks which phase cached this result.
        self.cached_in_recovery_phase: bool = False

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
            elif ((not self.result.is_mismatch and self.result.is_complete and not self.found_left_rec) or
                  phase_matches):
                if stats_module.parser_stats is not None:
                    stats_module.parser_stats.record_cache_hit()
                return self.result

        # Left recursion cycle detection
        if self.in_rec_path:
            if self.result is None:
                self.found_left_rec = True
                self.result = mismatch
            if self.result.is_mismatch:
                return lr_pending
            return self.result

        self.in_rec_path = True

        # Clear stale results before expansion loop
        if self.result is not None and (
            self.memo_version != parser.memo_version[pos] or
            (self.found_left_rec and self.cached_in_recovery_phase != parser.in_recovery_phase)
        ):
            self.result = None

        # Left recursion expansion loop
        while True:
            if stats_module.parser_stats is not None:
                stats_module.parser_stats.record_match()
            new_result = clause.match(parser, pos, bound=bound)

            if self.result is not None and new_result.len <= self.result.len:
                break  # No progress - fixed point reached

            self.result = new_result

            if not self.found_left_rec:
                break  # No left recursion - done in one iteration

            if stats_module.parser_stats is not None:
                stats_module.parser_stats.record_lr_expansion()
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
