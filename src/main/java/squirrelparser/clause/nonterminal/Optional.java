package squirrelparser.clause.nonterminal;

import squirrelparser.clause.Clause;
import squirrelparser.clause.Clause.ClauseWithOneSubClause;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

/**
 * Always matches, whether or not the subclause matches, but returns a match the same length as the subclause if the
 * subclause matches, or a zero-length match if the subclause does not match.
 */
public class Optional extends ClauseWithOneSubClause {
    public Optional(Clause subClause) {
        super(subClause);
    }

    @Override
    public Match match(int pos, int rulePos, Parser parser) {
        var subClauseMatch = subClause.match(pos, rulePos, parser);
        // Optional always matches, whether or not subclause matches
        return subClauseMatch == Match.NO_MATCH ? new Match(this, pos) : new Match(this, subClauseMatch);
    }

    @Override
    public String toString() {
        return labelClause(subClauseToString(subClause) + "?");
    }
}
