package squirrelparser.match;

public abstract class MatchResult {
	/** Return true if this MatchResult beats the other one. */
	public abstract boolean beats(MatchResult other);

	private static class NoMatch extends MatchResult {
		@Override
		public boolean beats(MatchResult other) {
			// NO_MATCH only beats no entry in the memo table
			return other == null;
		}
		
		@Override
		public String toString() {
			return "NO_MATCH";
		}
	}

	public static final NoMatch NO_MATCH = new NoMatch();
}
