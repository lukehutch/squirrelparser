package squirrelparser.match;

import squirrelparser.parser.ClauseAndPos;
import squirrelparser.parser.Parser;

public class MatchOptional extends Match {
	/** Subclause match, or null if subclause did not match. */
	public final Match subClauseMatch;

	public MatchOptional(ClauseAndPos clauseAndPos, Match subClauseMatch) {
		super(clauseAndPos, subClauseMatch.len);
		this.subClauseMatch = subClauseMatch;
	}

	@Override
	public boolean beats(MatchResult otherMatchResult) {
		if (otherMatchResult == null) {
			// A match of any sort beats no memo entry or no match
			return true;
		} else if (this.subClauseMatch == null) {
			// A non-matching Optional subclause cannot beat itself or a matching Optional
			// subclause
			return false;
		}
		var other = (MatchOptional) otherMatchResult;
		if (other.subClauseMatch == null) {
			// A matching Optional subclause beats a non-matching Optional subclause
			return true;
		}
		// A longer match beats a shorter match
		return this.subClauseMatch.len > ((Match) otherMatchResult).len;
	}

	public void print(int pos, int indent, Parser parser) {
		super.print(pos, indent, parser);
		if (subClauseMatch != null) {
			subClauseMatch.print(pos, indent + 1, parser);
		}
	}
}