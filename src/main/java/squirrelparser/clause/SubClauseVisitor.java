package squirrelparser.clause;

/**
 * Traverse the subclauses of this clause. Can also function as a clause rewriter, if the returned {@link Clause} is
 * different from the passed instance.
 */
@FunctionalInterface
public interface SubClauseVisitor {
    /**
     * Visit a subclause. Return the same subclause to leave the clause structure as-is, or return a different
     * {@link Clause} instance to rewrite the clause tree.
     */
    public Clause visit(Clause subClause);
}