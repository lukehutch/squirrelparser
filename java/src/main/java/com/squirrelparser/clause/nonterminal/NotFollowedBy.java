package com.squirrelparser.clause.nonterminal;

import static com.squirrelparser.parser.MatchResult.mismatch;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.parser.Match;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.Parser;

/**
 * Negative lookahead: succeeds if sub-clause fails, consumes nothing.
 */
public final class NotFollowedBy extends HasOneSubClause {
    public NotFollowedBy(Clause subClause) {
        super(subClause);
    }

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        MatchResult result = parser.match(subClause, pos, bound);
        return result.isMismatch() ? new Match(this, pos, 0) : mismatch();
    }

    @Override
    public String toString() {
        return "!" + subClause;
    }
}
