package squirrelparser.clause.nonterminal;

import java.util.Map;

import squirrelparser.clause.Clause;
import squirrelparser.match.Match;
import squirrelparser.parser.Parser;
import squirrelparser.rule.Rule;

public class RuleRef extends Clause {
	public final String refdRuleName;
	public Rule refdRule;

	public RuleRef(String refdRuleName) {
		this.refdRuleName = refdRuleName;
	}

	@Override
	public Match match(int pos, int rulePos, Parser parser) {
		return refdRule.match(pos, rulePos, parser);
	}

	@Override
	public void lookUpRuleRefs(Map<String, Rule> rules) {
		refdRule = rules.get(refdRuleName);
		if (refdRule == null) {
			throw new IllegalArgumentException("Grammar contains reference to non-existent rule: " + ruleName);
		}
	}

	@Override
	public String toString() {
		return refdRuleName;
	}
}
