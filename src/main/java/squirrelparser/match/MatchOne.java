package squirrelparser.match;

import squirrelparser.parser.ClauseAndPos;
import squirrelparser.parser.Parser;

public class MatchOne extends Match {
	public final Match subClauseMatch;

	public MatchOne(ClauseAndPos clauseAndPos, Match subclauseMatch) {
		super(clauseAndPos, subclauseMatch.len);
		this.subClauseMatch = subclauseMatch;
	}

	/** A longer match beats a shorter match. */
	@Override
	public boolean beats(MatchResult otherMatchResult) {
		return otherMatchResult == null || otherMatchResult == NO_MATCH //
				|| this.len > ((Match) otherMatchResult).len;
	}

	public void print(int pos, int indent, Parser parser) {
		super.print(pos, indent, parser);
		subClauseMatch.print(pos, indent + 1, parser);
	}
}