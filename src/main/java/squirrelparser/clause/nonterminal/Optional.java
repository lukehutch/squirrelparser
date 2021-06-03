package squirrelparser.clause.nonterminal;

import squirrelparser.clause.Clause;
import squirrelparser.clause.ClauseWithOneSubClause;
import squirrelparser.match.Match;
import squirrelparser.match.MatchOptional;
import squirrelparser.match.MatchResult;
import squirrelparser.parser.ClauseAndPos;
import squirrelparser.parser.Parser;

public class Optional extends ClauseWithOneSubClause {
	public Optional(Clause subClause) {
		super(subClause);
	}

	@Override
	public MatchResult match(ClauseAndPos clauseAndPos, Parser parser) {
		var subClauseMatchResult = parser.match(clauseAndPos.pos(),
				new ClauseAndPos(subClause, clauseAndPos.pos()));
		// Optional always matches, whether or not subclause matches
		return new MatchOptional(clauseAndPos,
				subClauseMatchResult == MatchResult.NO_MATCH ? null : (Match) subClauseMatchResult);
	}

	public String toStringInternal() {
		return subClause + "?";
	}
}
