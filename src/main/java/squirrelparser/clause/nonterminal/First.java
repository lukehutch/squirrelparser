package squirrelparser.clause.nonterminal;

import squirrelparser.clause.Clause;
import squirrelparser.clause.ClauseWithMultipleSubClauses;
import squirrelparser.match.Match;
import squirrelparser.match.MatchFirst;
import squirrelparser.match.MatchResult;
import squirrelparser.parser.ClauseAndPos;
import squirrelparser.parser.Parser;

public class First extends ClauseWithMultipleSubClauses {
	public First(Clause... subClauses) {
		super(subClauses);
	}

	@Override
	public MatchResult match(ClauseAndPos clauseAndPos, Parser parser) {
		for (int i = 0; i < subClauses.length; i++) {
			var subClauseMatchResult = parser.match(clauseAndPos.pos(),
					new ClauseAndPos(subClauses[i], clauseAndPos.pos()));
			if (subClauseMatchResult != MatchResult.NO_MATCH) {
				return new MatchFirst(clauseAndPos, (Match) subClauseMatchResult, i);
			}
		}
		return MatchResult.NO_MATCH;
	}

	public String toStringInternal() {
		StringBuilder buf = new StringBuilder();
		buf.append('(');
		for (int i = 0; i < subClauses.length; i++) {
			if (i > 0) {
				buf.append(" | ");
			}
			buf.append(subClauses[i]);
		}
		buf.append(')');
		return buf.toString();
	}
}
