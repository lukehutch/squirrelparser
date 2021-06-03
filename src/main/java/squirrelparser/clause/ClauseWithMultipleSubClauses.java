package squirrelparser.clause;

import java.util.Map;

import squirrelparser.rule.Rule;

public abstract class ClauseWithMultipleSubClauses extends Clause {
	public final Clause[] subClauses;

	public ClauseWithMultipleSubClauses(Clause... subClauses) {
		this.subClauses = subClauses;
	}

	@Override
	public void lookUpRuleRefs(Map<String, Rule> rules) {
		for (int i = 0; i < subClauses.length; i++) {
			subClauses[i].lookUpRuleRefs(rules);
		}
	}
}