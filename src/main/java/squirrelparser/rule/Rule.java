package squirrelparser.rule;

import squirrelparser.clause.Clause;
import squirrelparser.match.Match;
import squirrelparser.parser.Parser;

public class Rule {
	public final String ruleName;
	public final Clause clause;

	public Rule(String ruleName, Clause clause) {
		this.ruleName = ruleName;
		this.clause = clause;
	}

	public Match match(int pos, int parentRulePos, Parser parser) {
		var ruleAndPos = new RuleAndPos(this, pos);

		// Check whether we have reached a cycle
		var foundCycle = parser.cycleStart.containsKey(ruleAndPos);

		// Only check memo table if we have reached a cycle, or if parent frame and this frame have
		// different start positions
		if (foundCycle || pos != parentRulePos) {
			var memo = parser.memoTable.get(ruleAndPos);
			if (memo != null) {
				return memo;
			}
		}

		if (foundCycle) {
			// Reached infinite recursion cycle, and there was no previous memo for this clauseAndPos.
			// Mark cycle entry point as requiring iteration.
			parser.cycleStart.put(ruleAndPos, Boolean.TRUE);

			// The bottom-most closure of the cycle does not match.
			parser.memoTable.put(ruleAndPos, Match.NO_MATCH);
			return Match.NO_MATCH;
		}

		// Keep track of clause and start position in ancestral recursion frames.
		parser.cycleStart.put(ruleAndPos, Boolean.FALSE);

		boolean loop;
		do {
			var newMatch = clause.match(pos, /* rulePos = */ pos, parser);
			var oldMatch = parser.memoTable.get(ruleAndPos);
			if (newMatch.isBetterThan(oldMatch)) {
				// Found a new or improved match for this clause at this position
				parser.memoTable.put(ruleAndPos, newMatch);

				// Need to match this clause at this position again if this was marked as a cycle entry point
				// by the same clause being reached again at the same position during recursion
				loop = parser.cycleStart.get(ruleAndPos);
			} else {
				// Don't loop if match doesn't improve
				loop = false;
			}
		} while (loop);

		// Remove from visited set once this clause and position has finished recursing
		parser.cycleStart.remove(ruleAndPos);

		// Get best match so far
		var bestMatch = parser.memoTable.get(ruleAndPos);
		if (bestMatch != Match.NO_MATCH) {
			// Record this rule name in the top node of the match
			bestMatch.ruleName = ruleName;
		}
		return bestMatch;
	}

	@Override
	public String toString() {
		return ruleName + " <- " + clause;
	}
}
