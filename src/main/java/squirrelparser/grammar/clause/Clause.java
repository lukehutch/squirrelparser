package squirrelparser.grammar.clause;

import squirrelparser.grammar.Rule;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.ClauseUtils;

/** A grammar clause. A {@link Rule} contains a tree of {@link Clause} instances. */
public abstract class Clause {
    /** The rule, if this is the toplevel clause of a rule. */
    public Rule rule;

    /** The name of the AST node to generate if this node matches. */
    public String astNodeLabel;

    /**
     * Match this clause at the given position in the input.
     * 
     * @param pos     The start position to try matching from.
     * @param rulePos The position of the start of the rule that contains this clause.
     * @param parser  The {@link Parser}.
     * @return The {@link Match}, or {@link Match#NO_MATCH} if this clause did not match at this position.
     */
    public abstract Match match(int pos, int rulePos, Parser parser);

    /**
     * Traverse all subclauses of this clause, to search for information, and/or to rewrite the clause tree.
     * 
     * @param visitor The {@link SubClauseVisitor} to call for each subclause.
     */
    public void traverse(SubClauseVisitor visitor) {
    }

    /**
     * Prepend the AST node label of this clause to the {@link #toString()} representation of this clause, if this
     * clause is labeled.
     */
    protected String labelClause(String toString) {
        return astNodeLabel == null ? toString
                : ClauseUtils.needToAddParensAroundASTNodeLabel(this) ? astNodeLabel + ":(" + toString + ")"
                        : astNodeLabel + ":" + toString;
    }

    /**
     * Call {@link #toString()} for the given subclause, surrounding it with parentheses if needed (depending on the
     * precedence of this clause and the subclause).
     */
    protected String subClauseToString(Clause subClause) {
        return ClauseUtils.needToAddParensAroundSubClause(this, subClause) ? "(" + subClause + ")"
                : subClause.toString();
    }
}
