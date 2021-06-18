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
import squirrelparser.grammar.clause.SubClauseVisitor;

/** A grammar rule with optional precedence and optional associativity. */
public class PrecAssocRule {
    /** The name of the rule. */
    public String ruleName;

    /** The precedence of the rule, or -1 for no specified precedence. */
    public final int precedence;

    /** The associativity of the rule, or null for no specified associativity. */
    public final Associativity associativity;

    /** The toplevel clause of the rule. */
    public Clause clause;

    /** Construct a rule with specified precedence and associativity. */
    public PrecAssocRule(String ruleName, int precedence, Associativity associativity, Clause clause) {
        this.ruleName = ruleName;
        this.precedence = precedence;
        this.associativity = associativity;
        this.clause = clause;
    }

    /** Construct a rule with no specified precedence or associativity. */
    public PrecAssocRule(String ruleName, Clause clause) {
        // Use precedence of -1 for rules that only have one precedence
        // (this causes the precedence number not to be shown in the output of toStringWithRuleNames())
        this(ruleName, -1, /* associativity = */ null, clause);
    }

    /** Traverse the clause tree of this rule. */
    public void visit(SubClauseVisitor visitor) {
        clause = clause.visit(visitor);
    }

    @Override
    public String toString() {
        StringBuilder buf = new StringBuilder();
        buf.append(ruleName);
        buf.append(" <- ");
        buf.append(clause.toString());
        return buf.toString();
    }
}