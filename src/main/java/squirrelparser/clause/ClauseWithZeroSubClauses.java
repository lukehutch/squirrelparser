package squirrelparser.clause;

import java.util.Map;

public abstract class ClauseWithZeroSubClauses extends Clause {
	@Override
	public void replaceRuleRefs(Map<String, Clause> grammar) {
		// Do nothing
	}
}