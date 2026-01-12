package com.squirrelparser.clause.nonterminal;

import static com.squirrelparser.parser.MatchResult.mismatch;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.parser.Match;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.Parser;

/**
 * Positive lookahead: succeeds if sub-clause succeeds, consumes nothing.
 */
public final class FollowedBy extends HasOneSubClause {
    public FollowedBy(Clause subClause) {
        super(subClause);
    }

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        MatchResult result = parser.match(subClause, pos, bound);
        return result.isMismatch() ? mismatch() : new Match(this, pos, 0);
    }

    @Override
    public String toString() {
        return "&" + subClause;
    }
}
