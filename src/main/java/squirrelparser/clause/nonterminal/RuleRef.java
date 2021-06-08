package squirrelparser.clause.nonterminal;

import squirrelparser.clause.Clause;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.rule.Rule;

/** Matches if the named rule matches at the current position. */
public class RuleRef extends Clause {
    public String refdRuleName;
    public Rule refdRule;

    public RuleRef(String refdRuleName) {
        this.refdRuleName = refdRuleName;
    }

    @Override
    public Match match(int pos, int rulePos, Parser parser) {
        // Match the referenced rule
        var refdRuleMatch = refdRule.match(pos, rulePos, parser);
        if (astNodeLabel == null) {
            // This RuleRef clause doesn't have a separate AST node label; just reuse the Match from the
            // referenced rule
            return refdRuleMatch;
        } else {
            // Wrap the match of the referenced rule in a new Match, so that this RuleRef's AST node label
            // can be recorded in the parse tree
            return refdRuleMatch == Match.NO_MATCH ? Match.NO_MATCH
                    : new Match(this, /* subClauseMatch = */ refdRuleMatch);
        }
    }

    @Override
    public String toString() {
        return labelClause(refdRuleName);
    }
}
