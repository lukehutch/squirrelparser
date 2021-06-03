package squirrelparser.clause.nonterminal;

import java.util.ArrayList;

import squirrelparser.clause.Clause;
import squirrelparser.clause.Clause.ClauseWithOneSubClause;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

public class OneOrMore extends ClauseWithOneSubClause {
	public OneOrMore(Clause subClause) {
		super(subClause);
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
			return Match.NO_MATCH;
		} else {
			subClauseMatches.trimToSize();
			return new Match(this, pos, subClauseMatches);
		}
	}

	@Override
	public String toString() {
		return subClause + "+";
	}
}
