package com.squirrelparser;

import java.util.List;

/**
 * Result of matching a clause at a position.
 * Sealed interface with Match, Mismatch, and SyntaxError implementations.
 */
public sealed interface MatchResult permits Match, Mismatch, SyntaxError {
    Clause clause();
    int pos();
    int len();
    boolean isComplete();
    boolean isFromLRContext();
    List<MatchResult> subClauseMatches();

    default boolean isMismatch() {
        return false;
    }

    MatchResult withLRContext();

    String toPrettyString(String input, int indent);

    default String toPrettyString(String input) {
        return toPrettyString(input, 0);
    }
}

/**
 * Successful match result (unified type for all successful matches).
 * Terminals have empty children list, combinators have one or more children.
 */
record Match(
    Clause clause,
    int pos,
    int len,
    List<MatchResult> subClauseMatches,
    boolean isComplete,
    boolean isFromLRContext
) implements MatchResult {

    // Constructor for terminals (no children)
    public Match(Clause clause, int pos, int len) {
        this(clause, pos, len, List.of(), true, false);
    }

    // Constructor with children (auto-compute pos/len/isFromLR)
    public Match(Clause clause, List<MatchResult> subClauseMatches, boolean isComplete) {
        this(
            clause,
            subClauseMatches.isEmpty() ? 0 : subClauseMatches.get(0).pos(),
            subClauseMatches.isEmpty() ? 0 : totalLength(subClauseMatches),
            subClauseMatches,
            isComplete,
            anyFromLR(subClauseMatches)
        );
    }

    private static int totalLength(List<MatchResult> children) {
        if (children.isEmpty()) {
            return 0;
        }
        var last = children.get(children.size() - 1);
        return last.pos() + last.len() - children.get(0).pos();
    }

    private static boolean anyFromLR(List<MatchResult> children) {
        return children.stream().anyMatch(MatchResult::isFromLRContext);
    }

    @Override
    public MatchResult withLRContext() {
        return isFromLRContext ? this : new Match(clause, pos, len, subClauseMatches, isComplete, true);
    }

    @Override
    public String toPrettyString(String input, int indent) {
        var prefix = "  ".repeat(indent);
        String clauseName = "Unknown";
        if (clause != null) {
            // Check if it's a Ref without importing Ref
            if (clause.getClass().getSimpleName().equals("Ref")) {
                try {
                    var nameMethod = clause.getClass().getMethod("name");
                    clauseName = (String) nameMethod.invoke(clause);
                } catch (Exception e) {
                    clauseName = clause.getClass().getSimpleName();
                }
            } else {
                clauseName = clause.getClass().getSimpleName();
            }
        }

        var result = new StringBuilder();
        result.append(prefix).append(clauseName);

        if (subClauseMatches.isEmpty()) {
            result.append(": \"").append(input.substring(pos, pos + len)).append("\"");
        }

        result.append("\n");

        for (var child : subClauseMatches) {
            result.append(child.toPrettyString(input, indent + 1));
        }

        return result.toString();
    }
}

/**
 * Mismatch result (sentinel with len=-1 so even empty matches beat mismatches).
 */
record Mismatch(boolean isFromLRContext) implements MatchResult {

    public static final Mismatch INSTANCE = new Mismatch(false);
    public static final Mismatch LR_PENDING = new Mismatch(true);

    @Override
    public Clause clause() {
        return null;
    }

    @Override
    public int pos() {
        return -1;
    }

    @Override
    public int len() {
        return -1;
    }

    @Override
    public boolean isComplete() {
        return true;
    }

    @Override
    public List<MatchResult> subClauseMatches() {
        return List.of();
    }

    @Override
    public boolean isMismatch() {
        return true;
    }

    @Override
    public MatchResult withLRContext() {
        return LR_PENDING;
    }

    @Override
    public String toPrettyString(String input, int indent) {
        return "  ".repeat(indent) + "MISMATCH\n";
    }
}

