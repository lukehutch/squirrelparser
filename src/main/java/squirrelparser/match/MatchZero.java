package squirrelparser.match;

import squirrelparser.parser.ClauseAndPos;

public class MatchZero extends Match {
	public MatchZero(ClauseAndPos clauseAndPos) {
		super(clauseAndPos, 0);
	}

	@Override
	public boolean beats(MatchResult other) {
		return other == null || other == NO_MATCH;
	}
}