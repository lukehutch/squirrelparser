package squirrelparser.match;

import squirrelparser.parser.ClauseAndPos;

public class MatchFirst extends MatchOne {
	public final int firstMatchingSubclauseIdx;

	public MatchFirst(ClauseAndPos clauseAndPos, Match subclauseMatch, int firstMatchingSubclauseIdx) {
		super(clauseAndPos, subclauseMatch);
		this.firstMatchingSubclauseIdx = firstMatchingSubclauseIdx;
	}

	/**
	 * A smaller firstMatchingSubclauseIdx beats a larger firstMatchingSubclauseIdx,
	 * then a longer match beats a shorter match.
	 */
	@Override
	public boolean beats(MatchResult otherMatchResult) {
		if (otherMatchResult == null || otherMatchResult == NO_MATCH) {
			return true;
		}
		var other = (MatchFirst) otherMatchResult;
		// First check firstMatchingSubclauseIdx, then check len
		return this.firstMatchingSubclauseIdx < other.firstMatchingSubclauseIdx //
				|| this.len > other.len;
	}
}