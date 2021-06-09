//
// This file is part of the squirrel parser reference implementation:
//
//     https://github.com/lukehutch/squirrelparser
//
// This software is provided under the MIT license:
//
// Copyright 2021 Luke A. D. Hutchison
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions
// of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
// TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//
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
