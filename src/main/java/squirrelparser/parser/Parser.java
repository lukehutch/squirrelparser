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
package squirrelparser.parser;

import java.util.HashMap;
import java.util.Map;

import squirrelparser.grammar.Grammar;
import squirrelparser.grammar.Rule;
import squirrelparser.node.Match;

/** The parser (holds the memo table and other parsing information). */
public class Parser {
    /** The grammar. */
    public final Grammar grammar;

    /** The input to parse. */
    public final String input;

    /** The memo table. */
    public final Map<RuleAndPos, Match> memoTable = new HashMap<>();

    /**
     * A map allowing for fast lookup of the rules and positions of ancestral recursion frames, as well as for
     * looking up whether or not the current rule needs to iteratively continue to try to grow a left-recursive
     * match at the current position. There is one entry for each recursion frame in stack. The Boolean value
     * indicates whether or not a left-recursive cycle of the key's rule has been encountered yet in the grammar at
     * the key's position. A key is first put into the map with a false value, indicating that the key is on the
     * recursion path but a left-recursive cycle has not yet been encountered. If a left-recursive cycle is found
     * (i.e. a grammar cycle which revisits the same rule at the same position), then the value in the map is
     * switched from false to true, to notify the ancestral recursion frame that it needs to iteratively expand the
     * left recursion.
     */
    private final Map<RuleAndPos, Boolean> iterRuleAtPos = new HashMap<>();

    /** Construct a */
    public Parser(Grammar grammar, String input) {
        this.grammar = grammar;
        this.input = input;
    }

    /** Parse a rule while handling left recursion. */
    public Match match(Rule rule, int pos, int parentRulePos) {
        var ruleAndPos = new RuleAndPos(rule, pos);

        // If parent recursion frame and this recursion frame have different start positions,
        // check memo table before trying to recurse
        if (pos != parentRulePos) {
            var memo = memoTable.get(ruleAndPos);
            if (memo != null) {
                return memo;
            }
        }

        // Keep track of clause and start position in ancestral recursion frames.
        var oldIterRuleAtPos = iterRuleAtPos.putIfAbsent(ruleAndPos, Boolean.FALSE);

        if (oldIterRuleAtPos != null) {
            // Check memo table for lower matches when there's a left recursive cycle
            // (N.B. this is mutually exclusive with the memo table check above, because if
            // oldIterRuleAtPos != null, then pos must equal parentPos)
            var memo = memoTable.get(ruleAndPos);
            if (memo != null) {
                return memo;
            }
            // oldIterRuleAtPos must be FALSE here -- there will only be a memotable entry
            // if oldIterRuleAtPos was already marked as TRUE

            // Mark cycle entry point as requiring iteration.
            iterRuleAtPos.put(ruleAndPos, Boolean.TRUE);

            // The bottom-most invocation of the rule does not match (we grow the parse tree upwards from there)
            memoTable.put(ruleAndPos, Match.NO_MATCH);
            return Match.NO_MATCH;
        }

        // Left recursion expansion iteration loop (executes only once in the absence of left recursion)
        while (true) {
            // Try matching this rule's toplevel clause at this position
            var newMatch = rule.clause.match(this, pos, /* rulePos = */ pos);
            // Compare new match to old match in memo table, if any
            var oldMatch = memoTable.get(ruleAndPos);

            // A longer match beats a shorter match.
            // https://github.com/lukehutch/pikaparser/issues/32#issuecomment-861873964
            // N.B. NO_MATCH has a len of -1 so that even a zero-length match is better (longer) than NO_MATCH
            if (oldMatch != null && newMatch.len <= oldMatch.len) {
                // Match did not monotonically improve -- don't memoize (and stop iterating, if iterating)
                break;
            }

            // Memoize a new or improved match for this clause at this position
            memoTable.put(ruleAndPos, newMatch);

            if (!iterRuleAtPos.get(ruleAndPos)) {
                // This recursion frame was not marked for iteration by a lower recursion frame,
                // so don't iterate
                break;
            } // else keep iteratively matching until match can no longer be improved 
        }

        // Remove from visited set once this clause and position has finished recursing
        iterRuleAtPos.remove(ruleAndPos);

        // Return best match so far
        return memoTable.get(ruleAndPos);
    }

    /** Start parsing from the top rule at the beginning of the input. */
    public Match parse() {
        return match(grammar.topRule, 0, /* parentRulePos = */ -1);
    }
}
