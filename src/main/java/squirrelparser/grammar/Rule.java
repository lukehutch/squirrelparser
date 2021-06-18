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
package squirrelparser.grammar;

import squirrelparser.grammar.clause.Clause;
import squirrelparser.grammar.clause.SubClauseVisitor;

/** A PEG grammar rule. */
public class Rule {
    public final String ruleName;
    public Clause clause;

    public Rule(String ruleName, Clause clause) {
        this.ruleName = ruleName;
        this.clause = clause;
        this.clause.rule = this;
    }

    /** Traverse the clause tree of this rule. */
    public void traverse(SubClauseVisitor visitor) {
        var newClause = visitor.visit(clause);
        if (newClause != clause) {
            // If clause changes, move AST node label to new clause
            newClause.astNodeLabel = clause.astNodeLabel;
            clause.astNodeLabel = null;
            clause = newClause;
        }
        clause.traverse(visitor);
    }

    @Override
    public String toString() {
        return ruleName + " <- " + clause;
    }
}
