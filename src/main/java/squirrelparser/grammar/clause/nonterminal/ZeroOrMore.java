package squirrelparser.grammar.clause.nonterminal;

import java.util.ArrayList;

import squirrelparser.grammar.clause.Clause;
import squirrelparser.grammar.clause.ClauseWithOneSubClause;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

/** Always matches, consuming as many subclause matches as possible, starting at the current position. */
public class ZeroOrMore extends ClauseWithOneSubClause {
    public ZeroOrMore(Clause subClause) {
        super("", "*", subClause);
    }

    @Override
    public Match match(int pos, int rulePos, Parser parser) {
        ArrayList<Match> subClauseMatches = null;
        for (int currPos = pos;;) {
            var subClauseMatch = subClause.match(currPos, rulePos, parser);
            if (subClauseMatch == Match.NO_MATCH) {
                break;
            }
            if (subClauseMatches == null) {
                subClauseMatches = new ArrayList<>();
            }
            subClauseMatches.add(subClauseMatch);
            currPos += subClauseMatch.len;
            // If subclauseMatch.len == 0, then to avoid an infinite loop, only match once.
            if (subClauseMatch.len == 0) {
                break;
            }
        }
        if (subClauseMatches == null) {
            return new Match(this, pos);
        } else {
            subClauseMatches.trimToSize();
            return new Match(this, pos, subClauseMatches);
        }
    }
}
