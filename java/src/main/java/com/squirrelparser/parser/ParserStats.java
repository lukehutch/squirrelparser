package com.squirrelparser.parser;

/**
 * Statistics tracker for measuring parser work (validates O(n·|G|) complexity).
 */
public final class ParserStats {
    private static ParserStats instance = null;
    private static boolean debugLogging = false;

    private int clauseMatches = 0;
    private int cacheHits = 0;
    private int lrExpansions = 0;
    private int recoveryAttempts = 0;

    private ParserStats() {}

    /** Enable statistics tracking. */
    public static void enable() {
        instance = new ParserStats();
    }

    /** Disable statistics tracking. */
    public static void disable() {
        instance = null;
    }

    /** Get the current instance (may be null if disabled). */
    public static ParserStats get() {
        return instance;
    }

    /** Check if debug logging is enabled. */
    public static boolean isDebugLogging() {
        return debugLogging;
    }

    /** Set debug logging. */
    public static void setDebugLogging(boolean enabled) {
        debugLogging = enabled;
    }

    /** Total work performed (clause match attempts, not cache hits). */
    public int totalWork() {
        return clauseMatches;
    }

    /** Number of cache hits (memoization successes). */
    public int cacheHits() {
        return cacheHits;
    }

    /** Number of left recursion expansions. */
    public int lrExpansions() {
        return lrExpansions;
    }

    /** Number of recovery attempts. */
    public int recoveryAttempts() {
        return recoveryAttempts;
    }

    /** Record a clause match attempt. */
    public static void recordMatch() {
        if (instance != null) {
            instance.clauseMatches++;
        }
    }

    /** Record a cache hit. */
    public static void recordCacheHit() {
        if (instance != null) {
            instance.cacheHits++;
        }
    }

    /** Record a left recursion expansion. */
    public static void recordLRExpansion() {
        if (instance != null) {
            instance.lrExpansions++;
        }
    }

    /** Record a recovery attempt. */
    public static void recordRecovery() {
        if (instance != null) {
            instance.recoveryAttempts++;
        }
    }

    /** Reset all statistics. */
    public void reset() {
        clauseMatches = 0;
        cacheHits = 0;
        lrExpansions = 0;
        recoveryAttempts = 0;
    }
}
