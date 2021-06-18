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
import squirrelparser.grammar.clause.Clause;
import squirrelparser.node.Match;

/** The parser (holds the memo table and other parsing information). */
public class Parser {
    /** The grammar. */
    public final Grammar grammar;

    /** The input to parse. */
    public String input;

    /** The memo table. */
    public final Map<RulePos, MemoEntry> memoTable = new HashMap<>();

    /** Construct a */
    public Parser(Grammar grammar) {
        this.grammar = grammar;
    }

    /** Parse a rule while handling left recursion. */
    public Match match(Clause rule, int pos, int parentRuleStart) {
        var rulePos = new RulePos(rule, pos);
        var memoEntry = memoTable.computeIfAbsent(rulePos, rp -> new MemoEntry());

        // If parent recursion frame and this recursion frame have different start positions,
        // check memo table before trying to recurse
        if (pos != parentRuleStart && memoEntry.match != null) {
            // Return memo entry
            return memoEntry.match;
        }

        // Keep track of clause and start position in ancestral recursion frames.
        if (memoEntry.leftRecIter != null) {
            // rulePos is present at a higher stack frame in recursion path => hit a left-recursion cycle.
            if (!memoEntry.leftRecIter) {
                // Set leftRecIter to true if it is currently set to FALSE.
                memoEntry.leftRecIter = Boolean.TRUE;
            }
            if (memoEntry.match == null) {
                // Set memo entry to MISMATCH if a better match has not already been found.
                memoEntry.match = Match.MISMATCH;
            }
            // Return memo entry
            return memoEntry.match;
        }

        // rulePos is not present at a higher stack frame in recursion path
        memoEntry.leftRecIter = Boolean.FALSE;

        // Left recursion expansion iteration loop (executes only once in the absence of left recursion).
        // Don't need to look up bestMatch = memoTable.get(rulePos), because oldIterativelyMatch == null,
        // so this is the first time this rule has been matched at this position.
        Match bestMatch = memoEntry.match;
        while (true) {
            // Try matching this rule's toplevel clause at this position.
            // newMatch will be either MISMATCH if there was no match, or a Match reference if there was a match.
            var newMatch = rule.match(this, pos, /* rulePos = */ pos);

            // Break if newMatch is not better than bestMatch.
            // A longer match always beats a shorter match:
            // https://github.com/lukehutch/pikaparser/issues/32#issuecomment-861873964
            // N.B. MISMATCH has a len of -1 so that even a zero-length match is better (longer) than MISMATCH.
            if (bestMatch != null && newMatch.len <= bestMatch.len) {
                // Match did not monotonically improve -- don't memoize newMatch (and stop iterating, if iterating)
                break;
            }

            // Write the new or improved match to the memo entry
            memoEntry.match = newMatch;
            bestMatch = newMatch;

            // Check if this recursion frame was marked for iteration by a lower recursion frame
            // (need to check every iteration, since any iteration could result in triggering a new
            // path through a left-recursive cycle).
            if (!memoEntry.leftRecIter) {
                // No left recursion -- don't iterate.
                break;
            } // else keep iteratively matching until match can no longer be improved. 
        }

        // Unmark this clause for iteration at this position once iteration is finished
        memoEntry.leftRecIter = null;

        // Return the best match so far
        return bestMatch;
    }

    /** Start parsing from the top rule at the beginning of the input. */
    public Match parse(String input) {
        this.input = input;
        memoTable.clear();
        return match(grammar.topRule, 0, /* parentRuleStart = */ -1);
    }
}
