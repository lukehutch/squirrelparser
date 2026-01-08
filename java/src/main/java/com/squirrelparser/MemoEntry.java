package com.squirrelparser;

/**
 * A memo table entry for a (clause, position) pair.
 * Handles memoization, left-recursion detection, and expansion.
 */
class MemoEntry {
    private MatchResult result;
    private boolean inRecPath = false;
    private boolean foundLeftRec = false;
    private int memoVersion = 0;
    private boolean cachedInRecoveryPhase = false;

    /**
     * Match a clause at a position, handling left recursion and caching.
     */
    MatchResult match(Parser parser, Clause clause, int pos, Clause bound) {
        // Cache validation
        if (result != null && memoVersion == parser.getMemoVersion(pos)) {
            boolean phaseMatches = (cachedInRecoveryPhase == parser.inRecoveryPhase());

            // Top-level complete results that didn't reach EOF
            if (!result.isMismatch() && result.isComplete() && pos == 0 &&
                result.pos() + result.len() < parser.input().length() && !phaseMatches) {
                // Phase 1 result didn't reach EOF; retry in Phase 2
            } else if ((!result.isMismatch() && result.isComplete() && !foundLeftRec) || phaseMatches) {
                return result; // Cache hit
            }
        }

        // Left recursion cycle detection
        if (inRecPath) {
            if (result == null) {
                foundLeftRec = true;
                result = Mismatch.INSTANCE;
            }
            return result.isMismatch() ? Mismatch.LR_PENDING : result;
        }

        inRecPath = true;

        // Clear stale results before expansion loop
        if (result != null &&
            (memoVersion != parser.getMemoVersion(pos) ||
             (foundLeftRec && cachedInRecoveryPhase != parser.inRecoveryPhase()))) {
            result = null;
        }

        // Left recursion expansion loop
        while (true) {
            MatchResult newResult = clause.match(parser, pos, bound);

            if (result != null && newResult.len() <= result.len()) {
                break; // No progress - fixed point reached
            }

            result = newResult;

            if (!foundLeftRec) {
                break; // No left recursion - done in one iteration
            }

            parser.incrementMemoVersion(pos);
            memoVersion = parser.getMemoVersion(pos);
        }

        // Update cache metadata
        inRecPath = false;
        memoVersion = parser.getMemoVersion(pos);
        cachedInRecoveryPhase = parser.inRecoveryPhase();

        // Mark LR results
        if (foundLeftRec && !result.isMismatch() && !result.isFromLRContext()) {
            result = result.withLRContext();
        }

        return result;
    }
}
