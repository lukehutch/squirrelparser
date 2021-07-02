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

import org.parboiled2.Rule;

import squirrelparser.grammar.clause.Clause;
import squirrelparser.grammar.clause.nonterminal.RuleRef;
import squirrelparser.grammar.clause.nonterminal.Seq;
import squirrelparser.grammar.clause.terminal.Collect;
import squirrelparser.grammar.clause.terminal.Terminal;
import squirrelparser.utils.MetaGrammar;

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

        // Index rules by name
        var ruleMap = new HashMap<String, Clause>();
        for (var rule : rules) {
            if (rule.ruleName == null) {
                throw new IllegalArgumentException("Rule is not named: " + rule);
            }
            if (ruleMap.put(rule.ruleName, rule) != null) {
                throw new IllegalArgumentException("Two rules with the same name: " + rule.ruleName);
            }
        }

        // Look up rule reference for all RuleRef instances in rule clauses
        for (var i = 0; i < rules.size(); i++) {
            var rule = rules.get(i);
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
            rule.ruleIdx = i;
        }

        // Convert any Collect nodes into a tree of Terminal clauses that match much faster by not allocating
        // intermediate Match nodes. (Must be done after RuleRef refs have been resolved.)
        for (Clause rule : rules) {
            rule.visit(clause -> {
                if (clause instanceof Collect) {
                    ((Collect) clause).convert();
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
            buf.append(MetaGrammar.RULE_END_SYMBOL);
        }
        return buf.toString();
    }

    /** Convert a grammar to Java source. */
    public String toJavaSource() {
        var buf = new StringBuilder();
        buf.append("import " + Seq.class.getPackageName() + ".*;\n");
        buf.append("import " + Terminal.class.getPackageName() + ".*;\n");
        buf.append("import static " + MetaGrammar.class.getName() + ".rule;\n");
        buf.append("import java.util.Arrays;\n\n");
        buf.append("public class Parse {\n    public static void main(String[] args) {\n");
        buf.append("        var grammar = new Grammar(Arrays.asList(\n");
        for (int i = 0; i < rules.size(); i++) {
            var rule = rules.get(i);
            buf.append("            rule(\"" + rule.ruleName + "\", " + rule.toJavaSource() + ")");
            if (i < rules.size() - 1) {
                buf.append(',');
            }
            buf.append('\n');
        }
        buf.append("        ));\n    }\n}");
        return buf.toString();
    }
}
