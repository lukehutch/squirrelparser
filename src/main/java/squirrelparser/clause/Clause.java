package squirrelparser.clause;

import java.util.Map;

import squirrelparser.match.MatchResult;
import squirrelparser.parser.ClauseAndPos;
import squirrelparser.parser.Parser;

public abstract class Clause {
	public String ruleName;
	private String toStringCached;

	public abstract MatchResult match(ClauseAndPos clauseAndPos, Parser parser);

	public void setRuleName(String ruleName) {
		this.ruleName = ruleName;
	}

	public abstract void replaceRuleRefs(Map<String, Clause> grammar);
	
	protected abstract String toStringInternal();
	
	@Override
	public String toString() {
		if (toStringCached == null) {
			toStringCached = toStringInternal();
		}
		return toStringCached;
	}
}
