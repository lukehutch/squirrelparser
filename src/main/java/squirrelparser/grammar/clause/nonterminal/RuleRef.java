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
package squirrelparser.grammar.clause.nonterminal;

import squirrelparser.grammar.clause.Clause;
import squirrelparser.grammar.clause.SubClauseVisitor;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

/** Matches if the named rule matches at the current position. */
public class RuleRef extends Clause {
    /** The name of the referenced rule. */
    public String refdRuleName;

    /** The top clause in the referenced rule. */
    public Clause refdRule;

    public RuleRef(String refdRuleName) {
        this.refdRuleName = refdRuleName;
    }

    @Override
    public Match match(Parser parser, int pos) {
        // Recurse to match the referenced rule
        var refdRuleMatch = parser.match(refdRule, pos);
        if (astNodeLabel == null) {
            // This RuleRef clause doesn't have a separate AST node label; just reuse the Match from the
            // referenced rule
            return refdRuleMatch;
        } else if (refdRuleMatch != Match.MISMATCH) {
            return new Match(this, /* subClauseMatch = */ refdRuleMatch);
        } else {
            return Match.MISMATCH;
        }
    }

    @Override
    protected void visitSubclauses(SubClauseVisitor visitor) {
        // Don't traverse RuleRef reference when visiting clauses
    }

    @Override
    public String toString() {
        return labelClause(refdRuleName);
    }

    @Override
    public String toJavaSource() {
        return "new " + getClass().getSimpleName() + "(\"" + refdRuleName + "\")";
    }
}
