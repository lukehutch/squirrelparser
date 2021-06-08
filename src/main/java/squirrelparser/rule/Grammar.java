package squirrelparser.rule;

import java.util.HashMap;
import java.util.List;

import squirrelparser.clause.nonterminal.RuleRef;

public class Grammar {
    /** The rule to start parsing at. */
    public final Rule topRule;
    
    /** The rules in the grammar. */
    public final List<Rule> rules;

    /**
     * Create a grammar.
     * 
     * @param rules The list of grammar rules. The first rule should be the top rule of the grammar (i.e. the entry
     *              point for recursion).
     */
    public Grammar(List<Rule> rules) {
        if (rules == null || rules.isEmpty()) {
            throw new IllegalArgumentException("Grammar must contain at least one rule");
        }
        this.rules = rules;

        // Look up rule reference for all RuleRef instances in rule clauses
        var ruleMap = new HashMap<String, Rule>();
        for (var rule : rules) {
            ruleMap.put(rule.ruleName, rule);
        }
        for (var rule : rules) {
            rule.traverse(clause -> {
                if (clause instanceof RuleRef) {
                    var ruleRef = (RuleRef) clause;
                    ruleRef.refdRule = ruleMap.get(ruleRef.refdRuleName);
                    if (ruleRef.refdRule == null) {
                        throw new IllegalArgumentException(
                                "Grammar contains reference to non-existent rule: " + ruleRef.refdRuleName);
                    }
                }
                return clause;
            });
        }

        // Look up top rule of grammar
        this.topRule = rules.get(0);
    }
    
    @Override
    public String toString() {
        var buf = new StringBuilder();
        for (var rule : rules) {
            if (buf.length() > 0) {
                buf.append('\n');
            }
            buf.append(rule.toString());
            buf.append(';');
        }
        return buf.toString();
    }
}
