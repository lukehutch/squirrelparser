package squirrelparser.grammar.clause;

/** A {@link Clause} with multiple subclauses. */
public abstract class ClauseWithMultipleSubClauses extends Clause {
    /** The subclauses of this {@link Clause}. */
    public final Clause[] subClauses;

    private final String toStringSeparator;

    protected ClauseWithMultipleSubClauses(String toStringSeparator, Clause... subClauses) {
        this.toStringSeparator = toStringSeparator;
        this.subClauses = subClauses;
    }

    @Override
    public void traverse(SubClauseVisitor visitor) {
        for (int i = 0; i < subClauses.length; i++) {
            var newSubClause = visitor.visit(subClauses[i]);
            if (newSubClause != subClauses[i]) {
                // If subclause changes, move AST node label to new subclause
                newSubClause.astNodeLabel = subClauses[i].astNodeLabel;
                subClauses[i].astNodeLabel = null;
                subClauses[i] = newSubClause;
            }
            subClauses[i].traverse(visitor);
        }
    }

    @Override
    public String toString() {
        var buf = new StringBuilder();
        for (int i = 0; i < subClauses.length; i++) {
            if (i > 0) {
                buf.append(toStringSeparator);
            }
            buf.append(subClauseToString(subClauses[i]));
        }
        return labelClause(buf.toString());
    }
}