package com.squirrelparser;

import java.util.List;

/**
 * Syntax error node: records skipped input or deleted grammar elements.
 */
public record SyntaxError(
    int pos,
    int len,
    String skipped,
    boolean isDeletion
) implements MatchResult {

    public SyntaxError(int pos, int len, String skipped) {
        this(pos, len, skipped, false);
    }

    @Override
    public Clause clause() {
        return null;
    }

    @Override
    public boolean isComplete() {
        return true;
    }

    @Override
    public boolean isFromLRContext() {
        return false;
    }

    @Override
    public List<MatchResult> subClauseMatches() {
        return List.of();
    }

    @Override
    public MatchResult withLRContext() {
        return this; // SyntaxErrors don't need LR context
    }

    @Override
    public String toString() {
        return isDeletion ? "DELETION@" + pos : "SKIP(\"" + skipped + "\")@" + pos;
    }

    @Override
    public String toPrettyString(String input, int indent) {
        return "  ".repeat(indent) + this.toString() + "\n";
    }
}
