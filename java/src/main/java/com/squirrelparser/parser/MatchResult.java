package com.squirrelparser.parser;

import java.util.List;

import com.squirrelparser.clause.Clause;

/**
 * Result of matching a clause at a position.
 *
 * All match types (terminals, single child, multiple children) are unified.
 * They differ only in |children|: terminals (0), single (1), multiple (n).
 */
public abstract sealed class MatchResult permits Match, SyntaxError {
    private final Clause clause;
    private final int pos;
    private final int len;
    private final int totDescendantErrors;
    private final boolean isComplete;
    private final boolean isFromLRContext;

    protected MatchResult(Clause clause, int pos, int len, boolean isComplete,
                          boolean isFromLRContext, int totDescendantErrors) {
        this.clause = clause;
        this.pos = pos;
        this.len = len;
        this.isComplete = isComplete;
        this.isFromLRContext = isFromLRContext;
        this.totDescendantErrors = totDescendantErrors;
    }

    public Clause clause() { return clause; }
    public int pos() { return pos; }
    public int len() { return len; }
    public int totDescendantErrors() { return totDescendantErrors; }

    /**
     * CONSTRAINT C6 (Completeness Propagation): Signals whether this is a
     * maximal parse. A complete result means the grammar matched all input
     * it could, with no recovery needed. Incomplete means parsing could
     * continue but was blocked.
     */
    public boolean isComplete() { return isComplete; }

    /**
     * CONSTRAINT C10 (LR-Recovery Separation): Signals that this result came
     * from within a left-recursive expansion. Recovery must not be attempted
     * at results with this flag set.
     */
    public boolean isFromLRContext() { return isFromLRContext; }

    public abstract List<MatchResult> subClauseMatches();
    public boolean isMismatch() { return false; }

    /**
     * Create a copy of this result with isFromLRContext=true.
     * Used by MemoEntry to mark results from left-recursive rules (C10).
     */
    public abstract MatchResult withLRContext();

    public abstract String toPrettyString(String input, int indent);

    public String toPrettyString(String input) {
        return toPrettyString(input, 0);
    }

    // Static factory methods and constants
    private static final Match MISMATCH = new Match(null, -1, -1, List.of(), true, false, 0);
    private static final Match LR_PENDING = new Match(null, -1, -1, List.of(), true, true, 0);

    public static MatchResult mismatch() { return MISMATCH; }
    public static MatchResult lrPending() { return LR_PENDING; }

    // Helper functions
    static int totalLength(List<MatchResult> children) {
        if (children.isEmpty()) {
            return 0;
        }
        var first = children.getFirst();
        var last = children.getLast();
        return last.pos() + last.len() - first.pos();
    }

    static boolean anyFromLR(List<MatchResult> children) {
        return children.stream().anyMatch(MatchResult::isFromLRContext);
    }
}
