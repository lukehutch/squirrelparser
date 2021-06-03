package squirrelparser.match;

import squirrelparser.parser.ClauseAndPos;

public class MatchTerminal extends Match {
	public MatchTerminal(ClauseAndPos clauseAndPos, int len) {
		super(clauseAndPos, len);
	}

	@Override
	public boolean beats(MatchResult other) {
		return other == null;
	}
}