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

import java.util.HashMap;
import java.util.List;

import squirrelparser.grammar.clause.Clause;
import squirrelparser.grammar.clause.nonterminal.RuleRef;

/** A collection of {@link Rule} instances. */
public class Grammar {
    /** The rule to start parsing at. */
    public final Clause topRule;

    /** The rules in the grammar. */
    public List<Clause> rules;

    /**
     * Create a grammar.
     * 
     * @param rules The list of grammar rules. The first rule should be the top rule of the grammar (i.e. the entry
     *              point for recursion).
     */
    public Grammar(List<Clause> rules) {
        if (rules == null || rules.isEmpty()) {
            throw new IllegalArgumentException("Grammar must contain at least one rule");
        }
        this.rules = rules;

        // Look up rule reference for all RuleRef instances in rule clauses
        var ruleMap = new HashMap<String, Clause>();
        for (var rule : rules) {
            ruleMap.put(rule.ruleName, rule);
        }
        for (var rule : rules) {
            rule.visit(clause -> {
                if (clause instanceof RuleRef) {
                    var ruleRef = (RuleRef) clause;
                    ruleRef.refdRule = ruleMap.get(ruleRef.refdRuleName);
                    if (ruleRef.refdRule == null) {
                        throw new IllegalArgumentException(
                                "Grammar contains reference to non-existent rule: " + ruleRef.refdRuleName);
                    }
                }
                return clause;
            });
        }

        // Look up top rule of grammar
        this.topRule = rules.get(0);
    }

    @Override
    public String toString() {
        var buf = new StringBuilder();
        for (var rule : rules) {
            if (buf.length() > 0) {
                buf.append('\n');
            }
            buf.append(rule.toString());
            buf.append(';');
        }
        return buf.toString();
    }
}
