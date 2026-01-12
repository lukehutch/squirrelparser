package com.squirrelparser.clause.nonterminal;

import java.util.Map;

import com.squirrelparser.clause.Clause;

/**
 * Base class for clauses with one sub-clause.
 */
public abstract sealed class HasOneSubClause extends Clause permits Repetition, Optional, NotFollowedBy, FollowedBy {
    protected final Clause subClause;

    protected HasOneSubClause(Clause subClause) {
        this.subClause = subClause;
    }

    public Clause subClause() {
        return subClause;
    }

    @Override
    public void checkRuleRefs(Map<String, Clause> grammarMap) {
        subClause.checkRuleRefs(grammarMap);
    }
}
