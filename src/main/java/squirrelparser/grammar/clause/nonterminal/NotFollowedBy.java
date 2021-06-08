package squirrelparser.grammar.clause.nonterminal;

import squirrelparser.grammar.clause.Clause;
import squirrelparser.grammar.clause.ClauseWithOneSubClause;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

/** Matches, consuming zero characters, if the subclause does not match at the current position. */
public class NotFollowedBy extends ClauseWithOneSubClause {
    public NotFollowedBy(Clause subClause) {
        super("!", "", subClause);
    }

    @Override
    public Match match(int pos, int rulePos, Parser parser) {
        var subClauseMatch = subClause.match(pos, rulePos, parser);
        return subClauseMatch == Match.NO_MATCH ? new Match(this, pos) : Match.NO_MATCH;
    }
}
