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

import squirrelparser.grammar.Rule;
import squirrelparser.grammar.clause.Clause;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

/** Matches if the named rule matches at the current position. */
public class RuleRef extends Clause {
    public String refdRuleName;
    public Rule refdRule;

    public RuleRef(String refdRuleName) {
        this.refdRuleName = refdRuleName;
    }

    @Override
    public Match match(int pos, int rulePos, Parser parser) {
        // Match the referenced rule
        var refdRuleMatch = refdRule.match(pos, rulePos, parser);
        if (astNodeLabel == null) {
            // This RuleRef clause doesn't have a separate AST node label; just reuse the Match from the
            // referenced rule
            return refdRuleMatch;
        } else {
            // Wrap the match of the referenced rule in a new Match, so that this RuleRef's AST node label
            // can be recorded in the parse tree
            return refdRuleMatch == Match.NO_MATCH ? Match.NO_MATCH
                    : new Match(this, /* subClauseMatch = */ refdRuleMatch);
        }
    }

    @Override
    public String toString() {
        return labelClause(refdRuleName);
    }
}
