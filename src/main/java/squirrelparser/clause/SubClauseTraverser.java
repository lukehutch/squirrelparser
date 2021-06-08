package squirrelparser.clause;

/**
 * Traverse the subclauses of this clause. Can also function as a clause rewriter, if the returned
 * {@link Clause} is different from the passed instance.
 */
@FunctionalInterface
public interface SubClauseTraverser {
    public Clause traverse(Clause subClause);
}