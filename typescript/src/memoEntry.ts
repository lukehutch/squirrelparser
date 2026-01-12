import type { Clause } from './clause.js';
import type { MatchResult } from './matchResult.js';
import { mismatch, lrPending } from './matchResult.js';
import type { Parser } from './parser.js';
import { parserStats } from './parserStats.js';

// -----------------------------------------------------------------------------------------------------------------

/**
 * A memo table entry for a (clause, position) pair.
 *
 * SATISFIES:
 *   - A1 (Packrat Invariant): Memoization ensures each (clause, pos) evaluated once per phase
 *   - A4 (LR Fixed Point): Tracks inRecPath/foundLeftRec for cycle detection and expansion
 *   - C7 (Phase Isolation): cachedInRecoveryPhase prevents cross-phase pollution
 */
export class MemoEntry {
  private result: MatchResult | null = null;
  private inRecPath = false;       // Currently on call stack (for LR cycle detection)
  private foundLeftRec = false;    // Left recursion detected (triggers expansion)
  private memoVersion = 0;         // Version tag for LR seed invalidation

  /** CONSTRAINT C7 (Phase Isolation): Tracks which phase cached this result. */
  private cachedInRecoveryPhase = false;

  /**
   * Match a clause at a position, handling left recursion and caching.
   */
  match(parser: Parser, clause: Clause, pos: number, bound: Clause | undefined): MatchResult {
    // Cache validation (A1 - Packrat Invariant, C7 - Phase Isolation)
    if (this.result !== null && this.memoVersion === parser.memoVersion[pos]) {
      const phaseMatches = this.cachedInRecoveryPhase === parser.inRecoveryPhase;

      // Special case: Top-level complete results that didn't reach EOF
      if (!this.result.isMismatch &&
          this.result.isComplete &&
          pos === 0 &&
          this.result.pos + this.result.len < parser.input.length &&
          !phaseMatches) {
        // Phase 1 result didn't reach EOF; retry in Phase 2
      } else if ((!this.result.isMismatch && this.result.isComplete && !this.foundLeftRec) ||
                 phaseMatches) {
        parserStats?.recordCacheHit();
        return this.result;
      }
    }

    // Left recursion cycle detection
    if (this.inRecPath) {
      if (this.result === null) {
        this.foundLeftRec = true;
        this.result = mismatch;
      }
      if (this.result.isMismatch) {
        return lrPending;
      }
      return this.result;
    }

    this.inRecPath = true;

    // Clear stale results before expansion loop
    if (this.result !== null &&
        (this.memoVersion !== parser.memoVersion[pos] ||
         (this.foundLeftRec && this.cachedInRecoveryPhase !== parser.inRecoveryPhase))) {
      this.result = null;
    }

    // Left recursion expansion loop
    do {
      parserStats?.recordMatch();
      const newResult = clause.match(parser, pos, bound);

      if (this.result !== null && newResult.len <= this.result.len) {
        break; // No progress - fixed point reached
      }

      this.result = newResult;

      if (!this.foundLeftRec) {
        break; // No left recursion - done in one iteration
      }

      parserStats?.recordLRExpansion();
      parser.memoVersion[pos]++;
      this.memoVersion = parser.memoVersion[pos];
    // eslint-disable-next-line no-constant-condition
    } while (true);

    // Update cache metadata
    this.inRecPath = false;
    this.memoVersion = parser.memoVersion[pos];
    this.cachedInRecoveryPhase = parser.inRecoveryPhase;

    // Mark LR results
    if (this.foundLeftRec && !this.result!.isMismatch && !this.result!.isFromLRContext) {
      this.result = this.result!.withLRContext();
    }
    return this.result!;
  }
}
