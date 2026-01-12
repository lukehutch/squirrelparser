package com.squirrelparser.clause.nonterminal;

import java.util.List;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.parser.Match;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.Parser;

/**
 * Optional: matches zero or one instance.
 */
public final class Optional extends HasOneSubClause {
    public Optional(Clause subClause) {
        super(subClause);
    }

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        MatchResult result = parser.match(subClause, pos, bound);

        if (result.isMismatch()) {
            boolean incomplete = !parser.inRecoveryPhase() && pos < parser.input().length();
            return new Match(this, pos, 0, List.of(), !incomplete, false, 0);
        }

        return Match.withChildren(this, List.of(result), result.isComplete());
    }

    @Override
    public String toString() {
        return subClause + "?";
    }
}
