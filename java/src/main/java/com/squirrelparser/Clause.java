package com.squirrelparser;

/**
 * Base interface for all grammar clauses.
 */
public interface Clause {
    /**
     * If true, this clause is transparent in the AST - its children are promoted
     * to the parent rather than creating a node for this clause.
     */
    boolean transparent();

    /**
     * Match this clause at the given position in the parser's input.
     *
     * @param parser The parser instance
     * @param pos    The position to match at
     * @param bound  Optional boundary clause for recovery
     * @return Match result (Match, Mismatch, or SyntaxError)
     */
    MatchResult match(Parser parser, int pos, Clause bound);

    /**
     * Convenience method for matching without a bound.
     */
    default MatchResult match(Parser parser, int pos) {
        return match(parser, pos, null);
    }
}
