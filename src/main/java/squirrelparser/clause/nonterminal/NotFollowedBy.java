package squirrelparser.clause.nonterminal;

import squirrelparser.clause.Clause;
import squirrelparser.clause.Clause.ClauseWithOneSubClause;
import squirrelparser.match.Match;
import squirrelparser.parser.Parser;

public class NotFollowedBy extends ClauseWithOneSubClause {
	public NotFollowedBy(Clause subClause) {
		super(subClause);
	}

	@Override
	public Match match(int pos, int rulePos, Parser parser) {
		var subClauseMatch = subClause.match(pos, rulePos, parser);
		return subClauseMatch == Match.NO_MATCH ? new Match(this, pos) : Match.NO_MATCH;
	}

	@Override
	public String toString() {
		return "!" + subClause;
	}
}
