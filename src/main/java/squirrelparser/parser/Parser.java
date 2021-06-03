package squirrelparser.parser;

import java.util.HashMap;
import java.util.Map;

import squirrelparser.clause.Clause;
import squirrelparser.clause.nonterminal.RuleRef;
import squirrelparser.clause.nonterminal.Seq;
import squirrelparser.clause.terminal.Terminal;
import squirrelparser.match.Match;
import squirrelparser.match.MatchResult;

public class Parser {

	public static record X(int x) {
	}

	public final String input;

	private Clause topGrammarRuleClause;

	private final Map<ClauseAndPos, MatchResult> memoTable = new HashMap<>();

	/**
	 * One entry for each recursion frame in stack. Value indicates whether key is a
	 * cycle head or not.
	 */
	private final Map<ClauseAndPos, Boolean> ancestorBeginsCycle = new HashMap<>();

	public Parser(String input, Map<String, Clause> grammar, String topGrammarRuleName) {
		this.input = input;

		// Cache the toString() results for each clause before the RuleRefs are replaced, so that
		// toString() doesn't later get stuck in an infinite loop if the grammar contains cycles
		for (var ent : grammar.entrySet()) {
			var ruleName = ent.getKey();
			var ruleClause = ent.getValue();

			// Name the top clause of each rule
			ruleClause.setRuleName(ruleName);

			// Call toString() and cache the results
			ruleClause.toString();
		}

		// Replace all RuleRef instances with a direct link to the top clause of the
		// grammar
		for (var ent : grammar.entrySet()) {
			var ruleClause = ent.getValue();

			// Check top clause of rule is not a RuleRef -- this can lead to infinite cycles
			// (also if the top clause is not a RuleRef, then we don't need to ever follow
			// chains of RuleRefs to get to the final named rule, we can just do a single
			// lookup to determine which rule is being referred to)
			if (ruleClause instanceof RuleRef) {
				// Just wrap in Seq of length 1
				ruleClause = new Seq(ruleClause);
				ent.setValue(ruleClause);
			}

			// Replace any RuleRef clauses with references to the named rule
			ruleClause.replaceRuleRefs(grammar);
		}

		topGrammarRuleClause = grammar.get(topGrammarRuleName);
		if (topGrammarRuleClause == null) {
			throw new IllegalArgumentException("Top grammar rule " + topGrammarRuleName + " does not exist");
		}
	}

	public MatchResult parse() {
		// Parse input
		var parseResult = match(-1, new ClauseAndPos(topGrammarRuleClause, 0));

		System.out.println("\nParse result:");

		if (parseResult == MatchResult.NO_MATCH) {
			System.out.println("NO_MATCH");
		} else {
			((Match) parseResult).print(0, 0, this);
		}

		// TODO: Convert to CST
		return parseResult;
	}

	// TODO: move this method to Clause; create a memotable in each Clause; remove ClauseAndPos record type
	public MatchResult match(int parentPos, ClauseAndPos clauseAndPos) {
		// Match terminals without memoization
		if (clauseAndPos.clause() instanceof Terminal) {
			return clauseAndPos.clause().match(clauseAndPos, this);
		}

		// Check whether we have reached a cycle
		var foundCycle = ancestorBeginsCycle.containsKey(clauseAndPos);

		// Only check memo table if we have reached a cycle, or if parent frame and this frame have
		// different start positions
		if (foundCycle || clauseAndPos.pos() != parentPos) {
			var memo = memoTable.get(clauseAndPos);
			if (memo != null) {
				return memo;
			}
		}

		if (foundCycle) {
			// Reached infinite recursion cycle, and there was no previous memo for this clauseAndPos.
			// Mark cycle entry point as requiring iteration.
			ancestorBeginsCycle.put(clauseAndPos, Boolean.TRUE);

			// The bottom-most closure of the cycle does not match.
			memoTable.put(clauseAndPos, MatchResult.NO_MATCH);
			return MatchResult.NO_MATCH;
		}

		// Keep track of clause and start position in ancestral recursion frames.
		ancestorBeginsCycle.put(clauseAndPos, Boolean.FALSE);

		boolean loop;
		do {
			var newMatch = clauseAndPos.clause().match(clauseAndPos, this);
			var oldMatch = memoTable.get(clauseAndPos);
			if (newMatch.beats(oldMatch)) {
				// Found a new or improved match for this clause at this position
				memoTable.put(clauseAndPos, newMatch);

				// Need to match this clause at this position again if this was marked as a cycle entry point
				// by the same clause being reached again at the same position during recursion
				loop = ancestorBeginsCycle.get(clauseAndPos);
			} else {
				// Don't loop if match doesn't improve
				loop = false;
			}
		} while (loop);

		// Remove from visited set once this clause and position has finished recursing
		ancestorBeginsCycle.remove(clauseAndPos);

		// Return best memo entry so far
		return memoTable.get(clauseAndPos);
	}
}
