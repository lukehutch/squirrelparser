package squirrelparser.utils;

import squirrelparser.grammar.clause.Clause;
import squirrelparser.grammar.clause.nonterminal.First;
import squirrelparser.grammar.clause.nonterminal.Seq;
import squirrelparser.grammar.clause.terminal.Terminal;

public class ClauseUtils {
    /**
     * Return true if subClause precedence is less than or equal to parentClause precedence (or if subclause is a
     * {@link Seq} clause and parentClause is a {@link First} clause, for clarity, even though parens are not needed
     * because Seq has higher prrecedence).
     */
    public static boolean needToAddParensAroundSubClause(Clause parentClause, Clause subClause) {
        int clausePrec = parentClause instanceof Terminal ? MetaGrammar.clauseTypeToPrecedence.get(Terminal.class)
                : MetaGrammar.clauseTypeToPrecedence.get(parentClause.getClass());
        int subClausePrec = subClause instanceof Terminal ? MetaGrammar.clauseTypeToPrecedence.get(Terminal.class)
                : MetaGrammar.clauseTypeToPrecedence.get(subClause.getClass());
        if (subClause.astNodeLabel != null && subClausePrec < MetaGrammar.AST_NODE_LABEL_PRECEDENCE) {
            // If subclause has an AST node label and the labeled clause requires parens, then don't add
            // a second set of parens around the subclause
            return false;
        } else {
            // Always parenthesize Seq inside First for clarity, even though Seq has higher precedence
            return ((parentClause instanceof First && subClause instanceof Seq)
                    // Add parentheses around subclauses that are lower or equal precedence to parent clause
                    || subClausePrec <= clausePrec);
        }
    }

    /** Return true if subclause has lower precedence than an AST node label. */
    public static boolean needToAddParensAroundASTNodeLabel(Clause subClause) {
        int subClausePrec = subClause instanceof Terminal ? MetaGrammar.clauseTypeToPrecedence.get(Terminal.class)
                : MetaGrammar.clauseTypeToPrecedence.get(subClause.getClass());
        return subClausePrec < /* astNodeLabel precedence */ MetaGrammar.AST_NODE_LABEL_PRECEDENCE;
    }
}
