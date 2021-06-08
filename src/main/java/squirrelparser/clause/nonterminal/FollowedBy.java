package squirrelparser.clause.nonterminal;

import squirrelparser.clause.Clause;
import squirrelparser.clause.Clause.ClauseWithOneSubClause;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

/** Matches, consuming zero characters, if the subclause that is found to match at the current position. */
public class FollowedBy extends ClauseWithOneSubClause {
    public FollowedBy(Clause subClause) {
        super(subClause);
    }

    @Override
    public Match match(int pos, int rulePos, Parser parser) {
        var subClauseMatch = subClause.match(pos, rulePos, parser);
        return subClauseMatch == Match.NO_MATCH ? Match.NO_MATCH : new Match(this, pos);
    }

    @Override
    public String toString() {
        return labelClause("&" + subClauseToString(subClause));
    }
}
