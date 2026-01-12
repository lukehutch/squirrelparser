// -----------------------------------------------------------------------------------------------------------------

/**
 * Statistics tracker for measuring parser work (validates O(n·|G|) complexity).
 */
export class ParserStats {
  private _clauseMatches = 0;
  private _cacheHits = 0;
  private _lrExpansions = 0;
  private _recoveryAttempts = 0;

  /** Total work performed (clause match attempts, not cache hits). */
  get totalWork(): number {
    return this._clauseMatches;
  }

  /** Number of cache hits (memoization successes). */
  get cacheHits(): number {
    return this._cacheHits;
  }

  /** Number of left recursion expansions. */
  get lrExpansions(): number {
    return this._lrExpansions;
  }

  /** Number of recovery attempts. */
  get recoveryAttempts(): number {
    return this._recoveryAttempts;
  }

  /** Record a clause match attempt. */
  recordMatch(): void {
    this._clauseMatches++;
  }

  /** Record a cache hit. */
  recordCacheHit(): void {
    this._cacheHits++;
  }

  /** Record a left recursion expansion. */
  recordLRExpansion(): void {
    this._lrExpansions++;
  }

  /** Record a recovery attempt. */
  recordRecovery(): void {
    this._recoveryAttempts++;
  }

  /** Reset all statistics. */
  reset(): void {
    this._clauseMatches = 0;
    this._cacheHits = 0;
    this._lrExpansions = 0;
    this._recoveryAttempts = 0;
  }
}

// -----------------------------------------------------------------------------------------------------------------

/** Tracks parser work for linearity testing. Set to non-null to enable tracking. */
export let parserStats: ParserStats | null = null;

/** Enable parser statistics tracking. */
export function enableParserStats(): void {
  parserStats = new ParserStats();
}

/** Disable parser statistics tracking. */
export function disableParserStats(): void {
  parserStats = null;
}

// -----------------------------------------------------------------------------------------------------------------

/** Global debug logging flag for troubleshooting. */
export let debugLogging = false;

/** Set debug logging. */
export function setDebugLogging(enabled: boolean): void {
  debugLogging = enabled;
}
