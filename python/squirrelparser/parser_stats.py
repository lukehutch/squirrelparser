"""Statistics tracker for measuring parser work (validates O(n·|G|) complexity)."""

from __future__ import annotations


class ParserStats:
    """Statistics tracker for measuring parser work."""

    __slots__ = ('_clause_matches', '_cache_hits', '_lr_expansions', '_recovery_attempts')

    def __init__(self) -> None:
        self._clause_matches = 0
        self._cache_hits = 0
        self._lr_expansions = 0
        self._recovery_attempts = 0

    @property
    def total_work(self) -> int:
        """Total work performed (clause match attempts, not cache hits)."""
        return self._clause_matches

    @property
    def cache_hits(self) -> int:
        """Number of cache hits (memoization successes)."""
        return self._cache_hits

    @property
    def lr_expansions(self) -> int:
        """Number of left recursion expansions."""
        return self._lr_expansions

    @property
    def recovery_attempts(self) -> int:
        """Number of recovery attempts."""
        return self._recovery_attempts

    def record_match(self) -> None:
        """Record a clause match attempt."""
        self._clause_matches += 1

    def record_cache_hit(self) -> None:
        """Record a cache hit."""
        self._cache_hits += 1

    def record_lr_expansion(self) -> None:
        """Record a left recursion expansion."""
        self._lr_expansions += 1

    def record_recovery(self) -> None:
        """Record a recovery attempt."""
        self._recovery_attempts += 1

    def reset(self) -> None:
        """Reset all statistics."""
        self._clause_matches = 0
        self._cache_hits = 0
        self._lr_expansions = 0
        self._recovery_attempts = 0


# ------------------------------------------------------------------------------------------------------------------


# Tracks parser work for linearity testing. Set to non-None to enable tracking.
parser_stats: ParserStats | None = None

# Global debug logging flag for troubleshooting.
debug_logging: bool = False


def enable_parser_stats() -> None:
    """Enable parser statistics tracking."""
    global parser_stats
    parser_stats = ParserStats()


def disable_parser_stats() -> None:
    """Disable parser statistics tracking."""
    global parser_stats
    parser_stats = None


def set_debug_logging(enabled: bool) -> None:
    """Set debug logging."""
    global debug_logging
    debug_logging = enabled
