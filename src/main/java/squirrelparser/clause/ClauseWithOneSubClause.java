package squirrelparser.clause;

import java.util.Map;

import squirrelparser.clause.nonterminal.RuleRef;

public abstract class ClauseWithOneSubClause extends Clause {
	public Clause subClause;

	public ClauseWithOneSubClause(Clause subClause) {
		this.subClause = subClause;
	}

	@Override
	public void replaceRuleRefs(Map<String, Clause> grammar) {
		if (subClause instanceof RuleRef) {
			var refdRuleTopClause = grammar.get(((RuleRef) subClause).refdRuleName);
			if (refdRuleTopClause == null) {
				throw new IllegalArgumentException(
						"Grammar contains reference to non-existent rule: " + ((RuleRef) subClause).ruleName);
			}
			subClause = refdRuleTopClause;
		} else {
			// Recurse
			subClause.replaceRuleRefs(grammar);
		}
	}
}