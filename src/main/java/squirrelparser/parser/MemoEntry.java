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

import squirrelparser.grammar.clause.Clause;
import squirrelparser.node.Match;

/** An entry in the memo table. */
public class MemoEntry {
    /** The best {@link Match} found so far for this clause at this start position. */
    public Match match;

    /** If true, the memo table key (rule & position) corresponding to this memo entry is in the recursion path. */
    public boolean inRecPath;

    /** If true, a left-recursive cycle can be reached from this rule at this start position. */
    public boolean inLeftRecCycle;
    
    /** Parse a rule while handling left recursion. */
    Match match(Parser parser, Clause rule, int pos, int parentRuleStart) {
        // If parent recursion frame and this recursion frame have different start positions,
        // and there is a memo entry for this rule and position, return the memo entry rather
        // than duplicating work. (If pos == parentRuleStart, don't look at the memo table,
        // so that when expanding left-recursive cycles, lower matches don't prevent the
        // detection of higher matches in the parse tree.)
        if (pos != parentRuleStart && match != null) {
            return match;
        }

        // If we encountered the same rule and position twice in the recursion path, then we reached
        // a left-recursive cycle
        if (inRecPath) {
            // Mark this memo entry as being the "head node" in the left recursive cycle.
            // This effectively passes a message back up to the ancestral node with the same
            // rule and position to tell it to start iteratively growing the left-recursive
            // subtree of the parse tree.
            inLeftRecCycle = true;
            // When a left-recursive cycle is first found, the bottom-most node in the parse
            // tree corresponding to this clause at this position must be marked as a mismatch. 
            // However, if a better match was already found (e.g. because the ancestral "head of
            // the cylce" has iterated more than once), don't override that better match with
            // a mismatch.
            if (match == null) {
                match = Match.MISMATCH;
            }
            // Return memo entry for current-best match (starting with mismatch)
            return match;
        }

        // Otherwise no memo entry is available or usable, and no left recursive cycle has yet been detected --
        // recurse on this rule and position (i.e. perform standard recursive descent parsing).
        inRecPath = true;
        // No left recursion cycle is yet known
        inLeftRecCycle = false;
        
        // Left recursion expansion loop (executes only once if there no left recursive cycle is encountered).
        while (true) {
            // Try matching this rule's toplevel clause at this position.
            // newMatch will be either MISMATCH if there was no match, or a Match reference if there was a match.
            // Record the start position of the rule as the current position, so that when a RuleRef causes
            // recursion to return back to this method, whether or not the memo table should be consulted
            // can be checked (via the pos != parentRuleStart test, above).
            var newMatch = rule.match(parser, pos, /* ruleStart = */ pos);

            // Stop iterating if newMatch is not longer than bestMatch. This ensures this cycle will terminate,
            // because a left-recursive cycle must consume at least one extra character per loop around the cycle.
            // This is also true for First clauses, for very subtle reasons:
            // https://github.com/lukehutch/pikaparser/issues/32#issuecomment-861873964
            // N.B. Match.MISMATCH was defined to have a sentinel length of -1, so that even a zero-length match
            // always beats MISMATCH.
            if (match != null && newMatch.len <= match.len) {
                // Match did not monotonically improve -- don't memoize newMatch (and stop iterating, if iterating)
                break;
            }

            // Write the new or improved match to the memo table
            match = newMatch;

            // Check if this recursion frame was marked for iteration by a lower recursion frame
            // of the same rule and position detecting a left-recursive cycle had been reached
            // (see where this flag was set, above).
            if (!inLeftRecCycle) {
                // Not in a left-recursive cycle -- don't iterate.
                break;
            } // else keep iteratively matching until the match can no longer be improved. 
        }

        // On exit from this frame of recursion, mark this rule and position as is no longer being part of
        // the recursion path. (This is paired with "inRecPath = true;" before the while loop.) 
        inRecPath = false;

        // Return the best match so far
        return match;
    }
}