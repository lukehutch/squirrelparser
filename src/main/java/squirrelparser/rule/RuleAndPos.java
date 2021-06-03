package squirrelparser.rule;

public record RuleAndPos(Rule rule, int startPos) {
	@Override
	public String toString() {
		return rule.ruleName + "[" + rule.clause + "]" + ":" + startPos;
	}
}
