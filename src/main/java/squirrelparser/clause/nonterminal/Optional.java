package squirrelparser.clause.nonterminal;

import squirrelparser.clause.Clause;
import squirrelparser.clause.Clause.ClauseWithOneSubClause;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

public class Optional extends ClauseWithOneSubClause {
	public Optional(Clause subClause) {
		super(subClause);
	}

	@Override
	public Match match(int pos, int rulePos, Parser parser) {
		var subClauseMatch = subClause.match(pos, rulePos, parser);
		// Optional always matches, whether or not subclause matches
		return subClauseMatch == Match.NO_MATCH ? new Match(this, pos) : new Match(this, pos, subClauseMatch);
	}

	@Override
	public String toString() {
		return subClause + "?";
	}
}
