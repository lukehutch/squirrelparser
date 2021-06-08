package squirrelparser.clause.nonterminal;

import squirrelparser.clause.Clause;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.rule.Rule;

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
        if (refdRuleMatch != Match.NO_MATCH) {
            // Wrap the match of the referenced rule in a new match, so that RuleRefs can add their own
            // AST node labels to the AST, even if the referenced rule has its own AST node label
            return new Match(this, /* subClauseMatch = */ refdRuleMatch);
        } else {
            return Match.NO_MATCH;
        }
    }

    @Override
    public String toString() {
        return labelClause(refdRuleName);
    }
}
