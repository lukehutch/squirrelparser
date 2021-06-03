package squirrelparser.parser;

import java.util.Collection;
import java.util.HashMap;
import java.util.Map;

import squirrelparser.node.Match;
import squirrelparser.rule.Rule;
import squirrelparser.rule.RuleAndPos;

public class Parser {
	public final String input;

	private Rule topRule;

	public final Map<RuleAndPos, Match> memoTable = new HashMap<>();

	/** One entry for each recursion frame in stack. Value indicates whether key is a cycle head or not. */
	public final Map<RuleAndPos, Boolean> cycleStart = new HashMap<>();

	public Parser(String input, Collection<Rule> rules, String topRuleName) {
		this.input = input;

		// Look up rule reference for all RuleRef instances in rule clauses
		var ruleMap = new HashMap<String, Rule>();
		for (var rule : rules) {
			ruleMap.put(rule.ruleName, rule);
		}
		for (var rule : rules) {
			rule.clause.lookUpRuleRefs(ruleMap);
		}

		topRule = ruleMap.get(topRuleName);
		if (topRule == null) {
			throw new IllegalArgumentException("Top grammar rule " + topRuleName + " does not exist");
		}
	}

	public Match parse() {
		return topRule.match(0, /* parentRulePos = */ -1, this);
	}
}
