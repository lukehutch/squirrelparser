package com.squirrelparser.parser;

import static com.squirrelparser.parser.MatchResult.lrPending;
import static com.squirrelparser.parser.MatchResult.mismatch;

import com.squirrelparser.clause.Clause;

/**
 * A memo table entry for a (clause, position) pair.
 *
 * SATISFIES:
 *   - A1 (Packrat Invariant): Memoization ensures each (clause, pos) evaluated once per phase
 *   - A4 (LR Fixed Point): Tracks inRecPath/foundLeftRec for cycle detection and expansion
 *   - C7 (Phase Isolation): cachedInRecoveryPhase prevents cross-phase pollution
 */
public final class MemoEntry {
    private MatchResult result;
    private boolean inRecPath = false;     // Currently on call stack (for LR cycle detection)
    private boolean foundLeftRec = false;  // Left recursion detected (triggers expansion)
    private int memoVersion = 0;           // Version tag for LR seed invalidation

    /** CONSTRAINT C7 (Phase Isolation): Tracks which phase cached this result. */
    private boolean cachedInRecoveryPhase = false;

    /**
     * Match a clause at a position, handling left recursion and caching.
     */
    public MatchResult match(Parser parser, Clause clause, int pos, Clause bound) {
        // Cache validation (A1 - Packrat Invariant, C7 - Phase Isolation)
        if (result != null && memoVersion == parser.memoVersion()[pos]) {
            boolean phaseMatches = (cachedInRecoveryPhase == parser.inRecoveryPhase());

            // Special case: Top-level complete results that didn't reach EOF
            if (!result.isMismatch() &&
                result.isComplete() &&
                pos == 0 &&
                result.pos() + result.len() < parser.input().length() &&
                !phaseMatches) {
                // Phase 1 result didn't reach EOF; retry in Phase 2
            } else if ((!result.isMismatch() && result.isComplete() && !foundLeftRec) ||
                       phaseMatches) {
                ParserStats.recordCacheHit();
                return result;
            }
        }

        // Left recursion cycle detection
        if (inRecPath) {
            if (result == null) {
                foundLeftRec = true;
                result = mismatch();
            }
            if (result.isMismatch()) {
                return lrPending();
            }
            return result;
        }

        inRecPath = true;

        // Clear stale results before expansion loop
        if (result != null &&
            (memoVersion != parser.memoVersion()[pos] ||
             (foundLeftRec && cachedInRecoveryPhase != parser.inRecoveryPhase()))) {
            result = null;
        }

        // Left recursion expansion loop
        do {
            ParserStats.recordMatch();
            MatchResult newResult = clause.match(parser, pos, bound);

            if (result != null && newResult.len() <= result.len()) {
                break; // No progress - fixed point reached
            }

            result = newResult;

            if (!foundLeftRec) {
                break; // No left recursion - done in one iteration
            }

            ParserStats.recordLRExpansion();
            parser.memoVersion()[pos]++;
            memoVersion = parser.memoVersion()[pos];
        } while (true);

        // Update cache metadata
        inRecPath = false;
        memoVersion = parser.memoVersion()[pos];
        cachedInRecoveryPhase = parser.inRecoveryPhase();

        // Mark LR results
        if (foundLeftRec && !result.isMismatch() && !result.isFromLRContext()) {
            result = result.withLRContext();
        }
        return result;
    }
}
