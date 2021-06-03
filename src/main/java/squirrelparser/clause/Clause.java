package squirrelparser.clause;

import java.util.Map;

import squirrelparser.match.Match;
import squirrelparser.parser.Parser;
import squirrelparser.rule.Rule;

public abstract class Clause {
	public String ruleName;
	private String toStringCached;

	public abstract Match match(int pos, int rulePos, Parser parser);

	public void setRuleName(String ruleName) {
		this.ruleName = ruleName;
	}

	public void lookUpRuleRefs(Map<String, Rule> rules) {
	}
	
	protected abstract String toStringInternal();
	
	@Override
	public String toString() {
		if (toStringCached == null) {
			toStringCached = toStringInternal();
		}
		return toStringCached;
	}
}
