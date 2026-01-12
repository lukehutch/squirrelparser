package com.squirrelparser;

import java.util.Map;

/**
 * Abstract base class for terminal clauses.
 */
public abstract sealed class Terminal extends Clause permits Str, Char, CharSet, AnyChar, Nothing {
    /** The AST/CST node label for terminals. */
    public static final String NODE_LABEL = "<Terminal>";

    @Override
    public void checkRuleRefs(Map<String, Clause> grammarMap) {
        // Terminals have no references to check.
    }
}
