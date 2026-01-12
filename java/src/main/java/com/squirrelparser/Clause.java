package com.squirrelparser;

import java.util.Map;

/**
 * Base class for all grammar clauses.
 */
public abstract sealed class Clause permits Terminal, HasOneSubClause, HasMultipleSubClauses, Ref {

    /**
     * Match this clause at the given position.
     *
     * @param parser The parser instance
     * @param pos    The position in the input
     * @param bound  Optional bound clause for recovery
     * @return The match result
     */
    public abstract MatchResult match(Parser parser, int pos, Clause bound);

    /**
     * Check that all rule references in this clause are valid.
     *
     * @param grammarMap The map of rule names to clauses
     */
    public abstract void checkRuleRefs(Map<String, Clause> grammarMap);

    @Override
    public String toString() {
        return getClass().getSimpleName();
    }
}
