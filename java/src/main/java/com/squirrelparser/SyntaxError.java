package com.squirrelparser;

import java.util.List;

/**
 * A syntax error node: records skipped input or deleted grammar elements.
 * if len == 0, then this was a deletion of a grammar element, and clause is the deleted clause.
 * if len > 0, then this was an insertion of skipped input.
 */
public final class SyntaxError extends MatchResult {
    /** The AST/CST node label for syntax errors. */
    public static final String NODE_LABEL = "<SyntaxError>";

    public SyntaxError(int pos, int len, Clause deletedClause) {
        super(deletedClause, pos, len, true, false, 1);
    }

    public SyntaxError(int pos, int len) {
        this(pos, len, null);
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
        // If len == 0, this is a deletion of a grammar element;
        // if len > 0, this is an insertion of skipped input.
        return len() == 0
            ? "Missing grammar element " + (clause() != null ? clause().getClass().getSimpleName() : "unknown") + " at pos " + pos()
            : len() + " characters of unexpected input at pos " + pos();
    }

    @Override
    public String toPrettyString(String input, int indent) {
        return "  ".repeat(indent) + "<SyntaxError>: " + toString() + "\n";
    }
}
