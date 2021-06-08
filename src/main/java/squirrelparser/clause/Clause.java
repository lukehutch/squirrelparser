package squirrelparser.clause;

import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.rule.Rule;
import squirrelparser.utils.MetaGrammar;

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
     * Traverse the subclauses of this clause. Can also function as a clause rewriter, if the returned
     * {@link Clause} is different from the passed instance.
     */
    @FunctionalInterface
    public interface SubClauseTraverser {
        public Clause traverse(Clause subClause);
    }

    /**
     * Traverse all subclauses of this clause.
     * 
     * @param traverser The {@link SubClauseTraverser} to call for each subclause.
     */
    public void traverse(SubClauseTraverser traverser) {
        // Empty body for terminals
    }

    /** A {@link Clause} with multiple subclauses. */
    public static abstract class ClauseWithMultipleSubClauses extends Clause {
        /** The subclauses of this {@link Clause}. */
        public final Clause[] subClauses;

        public ClauseWithMultipleSubClauses(Clause... subClauses) {
            this.subClauses = subClauses;
        }

        @Override
        public void traverse(SubClauseTraverser traverser) {
            for (int i = 0; i < subClauses.length; i++) {
                var newSubClause = traverser.traverse(subClauses[i]);
                if (newSubClause != subClauses[i]) {
                    // If subclause changes, move AST node label to new subclause
                    newSubClause.astNodeLabel = subClauses[i].astNodeLabel;
                    subClauses[i].astNodeLabel = null;
                    subClauses[i] = newSubClause;
                }
                subClauses[i].traverse(traverser);
            }
        }
    }

    /** A {@link Clause} with one subclause. */
    public static abstract class ClauseWithOneSubClause extends Clause {
        /** The subclause of this {@link Clause}. */
        public Clause subClause;

        public ClauseWithOneSubClause(Clause subClause) {
            this.subClause = subClause;
        }

        @Override
        public void traverse(SubClauseTraverser traverser) {
            // Preorder traversal
            var newSubClause = traverser.traverse(subClause);
            if (newSubClause != subClause) {
                // If subclause changes, move AST node label to new subclause
                newSubClause.astNodeLabel = subClause.astNodeLabel;
                subClause.astNodeLabel = null;
                subClause = newSubClause;
            }
            subClause.traverse(traverser);
        }
    }

    /**
     * Prepend the AST node label of this clause to the {@link #toString()} representation of this clause, if this
     * clause is labeled.
     */
    protected String labelClause(String toString) {
        if (astNodeLabel == null) {
            return toString;
        } else if (MetaGrammar.needToAddParensAroundASTNodeLabel(this)) {
            return astNodeLabel + ":(" + toString + ")";
        } else {
            return astNodeLabel + ":" + toString;
        }
    }

    /**
     * Call {@link #toString()} for the given subclause, surrounding it with parentheses if needed (depending on the
     * precedence of this clause and the subclause).
     */
    protected String subClauseToString(Clause subClause) {
        if (MetaGrammar.needToAddParensAroundSubClause(this, subClause)) {
            return "(" + subClause + ")";
        } else {
            return subClause.toString();
        }
    }
}
