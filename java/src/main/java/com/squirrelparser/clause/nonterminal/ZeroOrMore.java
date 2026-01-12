package com.squirrelparser.clause.nonterminal;

import com.squirrelparser.clause.Clause;

/**
 * Zero or more repetitions.
 */
public final class ZeroOrMore extends Repetition {
    public ZeroOrMore(Clause subClause) {
        super(subClause, false);
    }

    @Override
    public String toString() {
        return subClause + "*";
    }
}
