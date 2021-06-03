package squirrelparser.match;

import squirrelparser.parser.ClauseAndPos;
import squirrelparser.parser.Parser;

public class MatchMultiple extends Match {
	public final Match[] subClauseMatches;

	public MatchMultiple(ClauseAndPos clauseAndPos, Match[] subclauseMatches) {
		super(clauseAndPos, totLen(subclauseMatches));
		this.subClauseMatches = subclauseMatches;
	}

	private static int totLen(Match[] subclauseMatches) {
		var len = 0;
		for (int i = 0; i < subclauseMatches.length; i++) {
			len += subclauseMatches[i].len;
		}
		return len;
	}

	@Override
	public boolean beats(MatchResult otherMatchResult) {
		if (otherMatchResult == null || otherMatchResult == NO_MATCH //
				|| this.len > ((Match) otherMatchResult).len) {
			return true;
		}
		var otherMatchMultiple = (MatchMultiple) otherMatchResult;
		if (this.subClauseMatches.length > otherMatchMultiple.subClauseMatches.length) {
			return true;
		}
		for (int i = 0; i < this.subClauseMatches.length; i++) {
			var ti = this.subClauseMatches[i];
			var oi = otherMatchMultiple.subClauseMatches[i];
			if (ti.len > oi.len) {
				return true;
			}
		}
		// Subclause matches have equal length
		return false;
	}

	public void print(int pos, int indent, Parser parser) {
		super.print(pos, indent, parser);
		for (int i = 0, currPos = pos; i < subClauseMatches.length; i++) {
			subClauseMatches[i].print(currPos, indent + 1, parser);
			currPos += subClauseMatches[i].len;
		}
	}
}