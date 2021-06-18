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

        // If parent recursion frame and this recursion frame have different start positions,
        // check memo table before trying to recurse
        if (pos != parentRulePos) {
            var memo = parser.memoTable.get(ruleAndPos);
            if (memo != null) {
                return memo;
            }
        }

        // Keep track of clause and start position in ancestral recursion frames.
        var oldIterRuleAtPos = parser.iterRuleAtPos.putIfAbsent(ruleAndPos, Boolean.FALSE);

        if (oldIterRuleAtPos != null) {
            // Check memo table for lower matches when there's a left recursive cycle
            // (N.B. this is mutually exclusive with the memo table check above, because if
            // oldIterRuleAtPos != null, then pos must equal parentPos)
            var memo = parser.memoTable.get(ruleAndPos);
            if (memo != null) {
                return memo;
            }
            // oldIterRuleAtPos must be FALSE here -- there will only be a memotable entry
            // if oldIterRuleAtPos was already marked as TRUE

            // Mark cycle entry point as requiring iteration.
            if (Parser.PREFER_LEFT_RECURSION) {
                // Only mark ancestral rule for iterative expansion of left recursion if there was
                // no ancestral rule yet marked for iteration at an earlier position
                if (parser.leftRecIterPos.putIfAbsent(this, pos) == null) {
                    parser.iterRuleAtPos.put(ruleAndPos, Boolean.TRUE);
                } // Else do not iterate in this position; already iterating rule at an earlier position
            } else {
                // Simpler algorithm produces right-associative parse tree from ambiguously associative rules
                parser.iterRuleAtPos.put(ruleAndPos, Boolean.TRUE);
            }

            // The bottom-most invocation of the rule does not match (we grow the parse tree upwards from there)
            parser.memoTable.put(ruleAndPos, Match.NO_MATCH);
            return Match.NO_MATCH;
        }

        // Left recursion expansion iteration loop (executes only once in the absence of left recursion)
        while (true) {
            // Try matching this rule's toplevel clause at this position
            var newMatch = clause.match(pos, /* rulePos = */ pos, parser);
            // Compare new match to old match in memo table, if any
            var oldMatch = parser.memoTable.get(ruleAndPos);

            // A longer match beats a shorter match.
            // https://github.com/lukehutch/pikaparser/issues/32#issuecomment-861873964
            // N.B. NO_MATCH has a len of -1 so that even a zero-length match is better (longer) than NO_MATCH
            if (oldMatch != null && newMatch.len <= oldMatch.len) {
                // Match did not monotonically improve -- don't memoize (and stop iterating, if iterating)
                break;
            }

            // Memoize a new or improved match for this clause at this position
            parser.memoTable.put(ruleAndPos, newMatch);

            if (!parser.iterRuleAtPos.get(ruleAndPos)) {
                // This recursion frame was not marked for iteration by a lower recursion frame,
                // so don't iterate
                break;
            } // else keep iteratively matching until match can no longer be improved 
        }

        // Remove from visited set once this clause and position has finished recursing
        parser.iterRuleAtPos.remove(ruleAndPos);
        if (Parser.PREFER_LEFT_RECURSION) {
            // Remove iterative expansion position, only if the value matches the current position
            parser.leftRecIterPos.remove(this, pos);
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
