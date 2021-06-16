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
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.parser.RuleAndPos;

/** A PEG grammar rule. */
public class Rule {
    public final String ruleName;
    public Clause clause;

    public Rule(String ruleName, Clause clause) {
        this.ruleName = ruleName;
        this.clause = clause;
        this.clause.rule = this;
    }

    /** Parse a rule while handling left recursion. */
    public Match match(int pos, int parentRulePos, Parser parser) {
        var ruleAndPos = new RuleAndPos(this, pos);

        var indent = Parser.DEBUG ? "  ".repeat(parser.cycleStart.size()) : null;

        // Check whether we have reached a cycle
        var foundCycle = parser.cycleStart.containsKey(ruleAndPos);

        // Only check memo table if we have reached a cycle, or if parent frame and this frame have
        // different start positions
        if (foundCycle || pos != parentRulePos) {
            var memo = parser.memoTable.get(ruleAndPos);
            if (memo != null) {
                if (Parser.DEBUG) {
                    System.out.println(indent + "MEMO MATCH: " + memo.toString(parser.input));
                }
                return memo;
            }
        }

        if (foundCycle) {
            // Reached infinite recursion cycle, and there was no previous memo for this clauseAndPos.
            // Mark cycle entry point as requiring iteration.
            parser.cycleStart.put(ruleAndPos, Boolean.TRUE);

            // The bottom-most closure of the cycle does not match.
            parser.memoTable.put(ruleAndPos, Match.NO_MATCH);
            if (Parser.DEBUG) {
                System.out.println(indent + "NO_MATCH: " + ruleAndPos);
            }
            return Match.NO_MATCH;
        }

        if (Parser.DEBUG) {
            System.out.println(indent + "Entering: " + ruleAndPos);
        }

        // Keep track of clause and start position in ancestral recursion frames.
        parser.cycleStart.put(ruleAndPos, Boolean.FALSE);

        // Left recursion expansion loop (executes only once if there is no left recursion)
        boolean loop;
        do {
            // Try matching this rule's toplevel clause at this position
            var newMatch = clause.match(pos, /* rulePos = */ pos, parser);
            // Compare new match to old match in memo table, if any
            var oldMatch = parser.memoTable.get(ruleAndPos);
            // A longer match beats a shorter match.
            // https://github.com/lukehutch/pikaparser/issues/32#issuecomment-861873964
            if (oldMatch == null || (oldMatch == Match.NO_MATCH && newMatch != Match.NO_MATCH)
                    || newMatch.len > oldMatch.len) {
                // Found a new or improved match for this clause at this position
                parser.memoTable.put(ruleAndPos, newMatch);
                if (Parser.DEBUG) {
                    System.out.println(indent + "  BETTER MATCH: " + newMatch.toString(parser.input));
                }
                // Check if this recursion frame was marked as a cycle start by a lower recursion frame,
                // and if so, need to loop until match can no longer be improved
                loop = parser.cycleStart.get(ruleAndPos);
            } else {
                // Don't loop if match doesn't improve
                if (Parser.DEBUG) {
                    System.out.println(indent + "  NO IMPROVEMENT: " + newMatch.toString(parser.input));
                }
                loop = false;
            }
        } while (loop);

        // Remove from visited set once this clause and position has finished recursing
        parser.cycleStart.remove(ruleAndPos);

        if (Parser.DEBUG) {
            System.out.println(indent + "Leaving: " + ruleAndPos);
        }

        // Return best match so far
        return parser.memoTable.get(ruleAndPos);
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
