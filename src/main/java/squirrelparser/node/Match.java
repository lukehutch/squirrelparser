package squirrelparser.node;

import java.util.Collections;
import java.util.List;

import squirrelparser.clause.Clause;
import squirrelparser.clause.nonterminal.First;
import squirrelparser.clause.nonterminal.OneOrMore;
import squirrelparser.clause.terminal.Terminal;
import squirrelparser.utils.StringUtils;

public class Match {
	public final Clause clause;
	public final int pos;
	public final int len;
	public final List<Match> subClauseMatches;
	public final int firstMatchingSubClauseIdx;
	public String ruleName;

	/** Used to return or memoize the notification that the clause did not match. */
	public static final Match NO_MATCH = new Match(null, -1, Collections.emptyList()) {
		@Override
		public boolean isBetterThan(Match other) {
			// NO_MATCH only beats there being no entry in the memo table
			return other == null;
		}

		@Override
		public String toString() {
			return "NO_MATCH";
		}
	};

	/** A match with multiple subclause matches. */
	public Match(Clause clause, int pos, List<Match> subClauseMatches) {
		this.clause = clause;
		this.pos = pos;
		var totLen = 0;
		for (int i = 0; i < subClauseMatches.size(); i++) {
			totLen += subClauseMatches.get(i).len;
		}
		this.len = totLen;
		this.subClauseMatches = subClauseMatches;
		this.firstMatchingSubClauseIdx = 0;
	}

	/** A match with a single subclause match. */
	public Match(Clause clause, int pos, Match subClauseMatch) {
		this.clause = clause;
		this.pos = pos;
		this.len = subClauseMatch.len;
		this.subClauseMatches = Collections.singletonList(subClauseMatch);
		this.firstMatchingSubClauseIdx = 0;
	}

	/** A match of a {@link First} clause, with one subclause match. */
	public Match(First clause, int pos, int matchingSubClauseIdx, Match subClauseMatch) {
		this.clause = clause;
		this.pos = pos;
		this.len = subClauseMatch.len;
		this.subClauseMatches = Collections.singletonList(subClauseMatch);
		this.firstMatchingSubClauseIdx = matchingSubClauseIdx;
	}

	/** A match of a {@link Terminal}. */
	public Match(Terminal clause, int pos, int len) {
		this.clause = clause;
		this.pos = pos;
		this.len = len;
		this.subClauseMatches = Collections.emptyList();
		this.firstMatchingSubClauseIdx = 0;
	}

	/** A match of zero length, with no subclause matches. */
	public Match(Clause clause, int pos) {
		this.clause = clause;
		this.pos = pos;
		this.len = 0;
		this.subClauseMatches = Collections.emptyList();
		this.firstMatchingSubClauseIdx = 0;
	}

	public void setRuleName(String ruleName) {
		this.ruleName = ruleName;
	}

	/**
	 * Returns true if this match is "better than" the other match, defined as having a lower first matching
	 * subclause index (for {@link First} clauses), or longer subclause matches, or matching more times (for
	 * {@link OneOrMore} clauses).
	 */
	public boolean isBetterThan(Match other) {
		if (other == null || other == NO_MATCH) {
			return true;
		}
		if (this.clause.getClass() != other.clause.getClass()) {
			throw new IllegalArgumentException("Comparing matches of different clause type");
		}
		// Compare first matching subclause index (for First)
		if (this.firstMatchingSubClauseIdx < other.firstMatchingSubClauseIdx) {
			return true;
		}
		// Greedily compare subclause match lengths, left-to-right
		for (int i = 0, min = Math.min(this.subClauseMatches.size(), other.subClauseMatches.size()); i < min; i++) {
			var ti = this.subClauseMatches.get(i);
			var oi = other.subClauseMatches.get(i);
			if (ti.len > oi.len) {
				return true;
			}
		}
		// Compare number of subclause matches (for OneOrMore)
		if (this.subClauseMatches.size() > other.subClauseMatches.size()) {
			return true;
		}
		// Matches are equal
		return false;
	}

	private void print(int indent, String input) {
		for (int i = 0; i < indent; i++) {
			System.out.print("--");
		}
		System.out.println(toString() + " : [" + StringUtils.escapeString(input.substring(pos, pos + len)) + "]");
		for (int i = 0; i < subClauseMatches.size(); i++) {
			subClauseMatches.get(i).print(indent + 1, input);
		}
	}

	/** Print the tree. */
	public void print(String input) {
		print(0, input);
	}

	@Override
	public String toString() {
		return (ruleName == null ? "" : ruleName + " <- ") + clause + " : " + pos + "+" + len;
	}
}