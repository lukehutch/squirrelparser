package squirrelparser.clause.nonterminal;

import squirrelparser.clause.ClauseWithZeroSubClauses;
import squirrelparser.match.MatchResult;
import squirrelparser.parser.ClauseAndPos;
import squirrelparser.parser.Parser;

public class RuleRef extends ClauseWithZeroSubClauses {
	public final String refdRuleName;

	public RuleRef(String refdRuleName) {
		this.refdRuleName = refdRuleName;
	}

	@Override
	public MatchResult match(ClauseAndPos clauseAndPos, Parser parser) {
		throw new IllegalArgumentException(
				"There should not be any " + RuleRef.class.getSimpleName() + " instances in final grammar");
	}

	public String toStringInternal() {
		return refdRuleName;
	}
}
