package squirrelparser.clause;

import java.util.Map;

import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.rule.Rule;

public abstract class Clause {
	public String ruleName;

	public abstract Match match(int pos, int rulePos, Parser parser);

	public void setRuleName(String ruleName) {
		this.ruleName = ruleName;
	}

	public void lookUpRuleRefs(Map<String, Rule> rules) {
	}

	public static abstract class ClauseWithMultipleSubClauses extends Clause {
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

	public static abstract class ClauseWithOneSubClause extends Clause {
		public Clause subClause;

		public ClauseWithOneSubClause(Clause subClause) {
			this.subClause = subClause;
		}

		@Override
		public void lookUpRuleRefs(Map<String, Rule> rules) {
			subClause.lookUpRuleRefs(rules);
		}
	}
}
