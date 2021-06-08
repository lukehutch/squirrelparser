package squirrelparser.utils;

import squirrelparser.clause.Clause;
import squirrelparser.clause.SubClauseTraverser;

/** A grammar rule with optional precedence and optional associativity. */
public class PrecAssocRule {
    /** The name of the rule. */
    public String ruleName;

    /** The precedence of the rule, or -1 for no specified precedence. */
    public final int precedence;

    /** The associativity of the rule, or null for no specified associativity. */
    public final Associativity associativity;

    /** The toplevel clause of the rule. */
    public Clause clause;

    /** Construct a rule with specified precedence and associativity. */
    public PrecAssocRule(String ruleName, int precedence, Associativity associativity, Clause clause) {
        this.ruleName = ruleName;
        this.precedence = precedence;
        this.associativity = associativity;
        this.clause = clause;
    }

    /** Construct a rule with no specified precedence or associativity. */
    public PrecAssocRule(String ruleName, Clause clause) {
        // Use precedence of -1 for rules that only have one precedence
        // (this causes the precedence number not to be shown in the output of toStringWithRuleNames())
        this(ruleName, -1, /* associativity = */ null, clause);
    }

    public void traverse(SubClauseTraverser traverser) {
        clause = traverser.traverse(clause);
        clause.traverse(traverser);
    }

    @Override
    public String toString() {
        StringBuilder buf = new StringBuilder();
        buf.append(ruleName);
        buf.append(" <- ");
        buf.append(clause.toString());
        return buf.toString();
    }
}