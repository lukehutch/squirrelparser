package squirrelparser.clause;

import java.util.Map;

import squirrelparser.clause.nonterminal.RuleRef;

public abstract class ClauseWithMultipleSubClauses extends Clause {
	public final Clause[] subClauses;

	public ClauseWithMultipleSubClauses(Clause... subClauses) {
		this.subClauses = subClauses;
	}

	@Override
	public void replaceRuleRefs(Map<String, Clause> grammar) {
		for (int i = 0; i < subClauses.length; i++) {
			if (subClauses[i] instanceof RuleRef) {
				var refdRuleTopClause = grammar.get(((RuleRef) subClauses[i]).refdRuleName);
				if (refdRuleTopClause == null) {
					throw new IllegalArgumentException("Grammar contains reference to non-existent rule: "
							+ ((RuleRef) subClauses[i]).ruleName);
				}
				subClauses[i] = refdRuleTopClause;
			} else {
				// Recurse
				subClauses[i].replaceRuleRefs(grammar);
			}
		}
	}
}