package squirrelparser.clause.nonterminal;

import squirrelparser.clause.Clause;
import squirrelparser.clause.ClauseWithMultipleSubClauses;
import squirrelparser.match.Match;
import squirrelparser.match.MatchMultiple;
import squirrelparser.match.MatchResult;
import squirrelparser.parser.ClauseAndPos;
import squirrelparser.parser.Parser;

public class Seq extends ClauseWithMultipleSubClauses {
	public Seq(Clause... subClauses) {
		super(subClauses);
	}

	@Override
	public MatchResult match(ClauseAndPos clauseAndPos, Parser parser) {
		Match[] subClauseMatches = null;
		int currPos = clauseAndPos.pos();
		for (int i = 0; i < subClauses.length; i++) {
			var subClauseMatchResult = parser.match(clauseAndPos.pos(), new ClauseAndPos(subClauses[i], currPos));
			if (subClauseMatchResult == MatchResult.NO_MATCH) {
				return MatchResult.NO_MATCH;
			}
			if (subClauseMatches == null) {
				subClauseMatches = new Match[subClauses.length];
			}
			var subClauseMatch = (Match) subClauseMatchResult;
			subClauseMatches[i] = subClauseMatch;
			currPos += subClauseMatch.len;
		}
		return new MatchMultiple(clauseAndPos, subClauseMatches);
	}

	public String toStringInternal() {
		StringBuilder buf = new StringBuilder();
		buf.append('(');
		for (int i = 0; i < subClauses.length; i++) {
			if (i > 0) {
				buf.append(' ');
			}
			buf.append(subClauses[i]);
		}
		buf.append(')');
		return buf.toString();
	}
}
