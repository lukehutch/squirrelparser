package com.squirrelparser.parser;

import java.util.List;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.clause.nonterminal.Ref;

/**
 * A successful match (unified type for all match results).
 * Terminals have empty children list, combinators have one or more children.
 */
public final class Match extends MatchResult {
    private final List<MatchResult> subClauseMatches;
    private final boolean isMismatch;

    /**
     * Create a match with explicit values.
     */
    public Match(Clause clause, int pos, int len, List<MatchResult> subClauseMatches,
                 boolean isComplete, boolean isFromLRContext, int totDescendantErrors) {
        super(clause,
              subClauseMatches.isEmpty() ? pos : subClauseMatches.getFirst().pos(),
              subClauseMatches.isEmpty() ? len : MatchResult.totalLength(subClauseMatches),
              isComplete,
              isFromLRContext,
              totDescendantErrors);
        this.subClauseMatches = subClauseMatches;
        this.isMismatch = (pos == -1 && len == -1);
    }

    /**
     * Create a match for a terminal (no children).
     */
    public Match(Clause clause, int pos, int len) {
        this(clause, pos, len, List.of(), true, false, 0);
    }

    /**
     * Create a match with children, computing derived values automatically.
     */
    public Match(Clause clause, int pos, int len, List<MatchResult> subClauseMatches,
                 boolean isComplete, Boolean isFromLRContext, int numSyntaxErrors,
                 boolean addSubClauseErrors) {
        super(clause,
              subClauseMatches.isEmpty() ? pos : subClauseMatches.getFirst().pos(),
              subClauseMatches.isEmpty() ? len : MatchResult.totalLength(subClauseMatches),
              isComplete,
              isFromLRContext != null ? isFromLRContext :
                  (subClauseMatches.isEmpty() ? false : MatchResult.anyFromLR(subClauseMatches)),
              addSubClauseErrors ?
                  numSyntaxErrors + subClauseMatches.stream().mapToInt(MatchResult::totDescendantErrors).sum() :
                  numSyntaxErrors);
        this.subClauseMatches = subClauseMatches;
        this.isMismatch = (pos == -1 && len == -1 && subClauseMatches.isEmpty());
    }

    /**
     * Builder-style factory for convenient construction.
     */
    public static Match of(Clause clause, int pos, int len) {
        return new Match(clause, pos, len);
    }

    public static Match withChildren(Clause clause, List<MatchResult> children, boolean isComplete) {
        return new Match(clause, 0, 0, children, isComplete, null, 0, true);
    }

    @Override
    public List<MatchResult> subClauseMatches() {
        return subClauseMatches;
    }

    @Override
    public boolean isMismatch() {
        return isMismatch;
    }

    @Override
    public MatchResult withLRContext() {
        if (isMismatch) {
            return MatchResult.lrPending();
        }
        if (isFromLRContext()) {
            return this;
        }
        return new Match(clause(), pos(), len(), subClauseMatches, isComplete(), true,
                         totDescendantErrors(), false);
    }

    @Override
    public String toPrettyString(String input, int indent) {
        var buffer = new StringBuilder();
        buffer.append("  ".repeat(indent));
        if (isMismatch) {
            buffer.append("MISMATCH\n");
            return buffer.toString();
        }
        buffer.append(clause() instanceof Ref ? clause().toString() : clause().getClass().getSimpleName());
        if (subClauseMatches.isEmpty()) {
            buffer.append(": \"").append(input.substring(pos(), pos() + len())).append("\"");
        }
        buffer.append("\n");
        for (var child : subClauseMatches) {
            buffer.append(child.toPrettyString(input, indent + 1));
        }
        return buffer.toString();
    }
}
