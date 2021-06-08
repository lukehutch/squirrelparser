package squirrelparser.grammar.clause;

/** A {@link Clause} with one subclause. */
public abstract class ClauseWithOneSubClause extends Clause {
    /** The subclause of this {@link Clause}. */
    public Clause subClause;

    private String toStringPrefix;

    private String toStringSuffix;

    protected ClauseWithOneSubClause(String toStringPrefix, String toStringSuffix, Clause subClause) {
        this.toStringPrefix = toStringPrefix;
        this.toStringSuffix = toStringSuffix;
        this.subClause = subClause;
    }

    @Override
    public void traverse(SubClauseVisitor visitor) {
        // Preorder traversal
        var newSubClause = visitor.visit(subClause);
        if (newSubClause != subClause) {
            // If subclause changes, move AST node label to new subclause
            newSubClause.astNodeLabel = subClause.astNodeLabel;
            subClause.astNodeLabel = null;
            subClause = newSubClause;
        }
        subClause.traverse(visitor);
    }

    @Override
    public String toString() {
        return labelClause(labelClause(toStringPrefix + subClauseToString(subClause) + toStringSuffix));
    }
}