package com.squirrelparser.clause.nonterminal;

import com.squirrelparser.clause.Clause;

/**
 * One or more repetitions.
 */
public final class OneOrMore extends Repetition {
    public OneOrMore(Clause subClause) {
        super(subClause, true);
    }

    @Override
    public String toString() {
        return subClause + "+";
    }
}
