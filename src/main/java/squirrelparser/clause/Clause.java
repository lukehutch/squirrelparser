package squirrelparser.clause;

import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.rule.Rule;
import squirrelparser.utils.MetaGrammar;

public abstract class Clause {
    /** The rule, if this is the toplevel clause of a rule. */
    public Rule rule;

    /** The name of the AST node to generate if this node matches. */
    public String astNodeLabel;

    public abstract Match match(int pos, int rulePos, Parser parser);

    /**
     * Traverse the subclauses of this clause. Can also function as a clause rewriter, if the returned
     * {@link Clause} is different from the passed instance.
     */
    @FunctionalInterface
    public interface SubClauseTraverser {
        public Clause traverse(Clause subClause);
    }

    public void traverse(SubClauseTraverser traverser) {
        // Empty body for terminals
    }

    public static abstract class ClauseWithMultipleSubClauses extends Clause {
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

    public static abstract class ClauseWithOneSubClause extends Clause {
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

    protected String labelClause(String toString) {
        if (astNodeLabel == null) {
            return toString;
        } else if (MetaGrammar.needToAddParensAroundASTNodeLabel(this)) {
            return astNodeLabel + ":(" + toString + ")";
        } else {
            return astNodeLabel + ":" + toString;
        }
    }

    protected String subClauseToString(Clause subClause) {
        if (MetaGrammar.needToAddParensAroundSubClause(this, subClause)) {
            return "(" + subClause + ")";
        } else {
            return subClause.toString();
        }
    }
}
