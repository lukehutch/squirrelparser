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
     * @param parser  The {@link Parser}.
     * @param pos     The start position to try matching from.
     * @param rulePos The position of the start of the rule that contains this clause.
     * 
     * @return The {@link Match}, or {@link Match#NO_MATCH} if this clause did not match at this position.
     */
    public abstract Match match(Parser parser, int pos, int rulePos);

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
