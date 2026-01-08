/// Statistics tracker for measuring parser work (validates O(n·|G|) complexity).
class ParserStats {
  int _clauseMatches = 0;
  int _cacheHits = 0;
  int _lrExpansions = 0;
  int _recoveryAttempts = 0;

  /// Total work performed (clause match attempts, not cache hits).
  int get totalWork => _clauseMatches;

  /// Number of cache hits (memoization successes).
  int get cacheHits => _cacheHits;

  /// Number of left recursion expansions.
  int get lrExpansions => _lrExpansions;

  /// Number of recovery attempts.
  int get recoveryAttempts => _recoveryAttempts;

  /// Record a clause match attempt.
  void recordMatch() => _clauseMatches++;

  /// Record a cache hit.
  void recordCacheHit() => _cacheHits++;

  /// Record a left recursion expansion.
  void recordLRExpansion() => _lrExpansions++;

  /// Record a recovery attempt.
  void recordRecovery() => _recoveryAttempts++;

  /// Reset all statistics.
  void reset() {
    _clauseMatches = 0;
    _cacheHits = 0;
    _lrExpansions = 0;
    _recoveryAttempts = 0;
  }
}

/// Tracks parser work for linearity testing. Set to non-null to enable tracking.
ParserStats? parserStats;

/// Global debug logging flag for troubleshooting.
bool debugLogging = false; // Set to true for detailed logging
