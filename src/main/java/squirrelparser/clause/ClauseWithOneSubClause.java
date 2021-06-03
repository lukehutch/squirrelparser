package squirrelparser.clause;

import java.util.Map;

import squirrelparser.rule.Rule;

public abstract class ClauseWithOneSubClause extends Clause {
	public Clause subClause;

	public ClauseWithOneSubClause(Clause subClause) {
		this.subClause = subClause;
	}

	@Override
	public void lookUpRuleRefs(Map<String, Rule> rules) {
		subClause.lookUpRuleRefs(rules);
	}
}