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

/** An entry in the memo table, for a specific {@link RulePos}. */
public class MemoEntry {
    /** The best {@link Match} found so far for this rule at this position. */
    public Match match;

    /** If true, the rule and position of this memo entry is in the recursion path. */
    private boolean inRecPath;

    /** If true, this rule is the head of a left-recursive cycle at the current position. */
    private boolean inLeftRecCycle;

    private int cycleDepth;

    /** Parse a rule while handling left recursion. */
    Match match(Parser parser, Clause rule, int pos) {
        var indent = Parser.DEBUG ? "|   ".repeat(parser.recursionDepth - 1) : null;
        if (Parser.DEBUG) {
            System.out.println(indent + "Entering: " + rule + " : " + pos);
        }
        // If parent recursion frame and this recursion frame have different start positions,
        // and there is a memo entry for this rule and position, return the memo entry rather
        // than duplicating work. In other words, if (pos != parentRuleStart && match != null),
        // just return the memoized match, but if (pos == parentRuleStart || match == null), don't
        // look at the memo table. In particular, don't look at the memo table
        // if (pos == parentRuleStart), even if (match != null), so that when expanding
        // left-recursive cycles, lower matches don't prevent the detection of higher matches
        // in the parse tree.)
        if (cycleDepth < parser.cycleDepthForPos[pos] || match == null) {
            if (inRecPath) {
                if (Parser.DEBUG) {
                    System.out.println(indent + "In rec path for: " + rule + " : " + pos);
                }
                if (match == null) {
                    if (Parser.DEBUG) {
                        System.out.println(indent + "Seed match: " + rule + " : " + pos + " => MISMATCH");
                    }
                    // If we encountered the same rule and position twice in the recursion path, and there
                    // is not yet a memo entry in the memo table, then we hit a left-recursive cycle
                    // for the first time.
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
                    match = Match.MISMATCH;
                    // Initial cycleDepth for a mismatch will usually be 0, but may be greater than 0
                    // if there are two interwoven cycles.
                    cycleDepth = parser.cycleDepthForPos[pos];
                } else {
                    if (Parser.DEBUG) {
                        System.out.println(indent + "Using memo: "
                                + (match == Match.MISMATCH ? rule + " : " + pos + " => MISMATCH" : match));
                    }
                    // Otherwise if we reached the same clause twice on the recursion path, but there's
                    // already a memo in the memo table for this clause, then fall through, and just
                    // return the match from the memo table. There's no need to expand a left recursive
                    // cycle -- that would have already been done if it were needed.
                }
            } else {
                if (Parser.DEBUG) {
                    System.out.println(indent + "Not in rec path for: " + rule + " : " + pos);
                }
                // Otherwise no memo entry is available or usable, and no left recursive cycle has yet been
                // detected -- recurse on this rule and position (i.e. perform standard recursive descent
                // parsing).
                inRecPath = true;

                // Left recursion expansion loop (executes only once if there no left recursive cycle is
                // encountered). No left recursion cycle is yet known.
                inLeftRecCycle = false;
                while (true) {
                    // Try matching this rule's toplevel clause at this position. newMatch will be either MISMATCH
                    // if there was no match, or a Match reference if there was a match.
                    // Record the start position of the rule as the current position, so that when a RuleRef causes
                    // recursion to return back to this method, whether or not the memo table should be consulted
                    // can be checked (via the pos != parentRuleStart test, above).
                    var newMatch = rule.match(parser, pos);
                    if (Parser.DEBUG) {
                        System.out.println(indent + "New match: "
                                + (newMatch == Match.MISMATCH ? rule + " : " + pos + " => MISMATCH" : newMatch));
                    }

                    // Update cycleDepth, whether or not match improved, to avoid duplicating work in
                    // "cousin clauses" (where the same RuleRef occurs multiple times within the clause
                    // tree of a single rule). This "upgrades" the cycleDepth of the match or mismatch,
                    // in keeping with the logic that a memo should only be updated if the match gets
                    // longer. i.e. Once a clause goes from matching to mismatching, its longest match
                    // is always considered the current best match.
                    cycleDepth = parser.cycleDepthForPos[pos];

                    // Stop iterating if newMatch is not longer than bestMatch. This ensures this cycle will
                    // terminate, because a left-recursive cycle must consume at least one extra character per
                    // loop around the cycle. This is also true for First clauses, for very subtle reasons:
                    // https://github.com/lukehutch/pikaparser/issues/32#issuecomment-861873964
                    // N.B. Match.MISMATCH was defined to have a sentinel length of -1, so that even a
                    // zero-length match always beats MISMATCH.
                    if (match != null && newMatch.len <= match.len) {
                        // Match did not monotonically improve -- don't memoize newMatch, and stop iterating.
                        if (Parser.DEBUG) {
                            System.out.println(indent + "Match did not improve compared to old match: " + match);
                        }
                        break;
                    }

                    // Write the new or improved match to the memo table
                    match = newMatch;

                    // Check if this recursion frame was marked for iterative expansion of a left-recursive
                    // cycle by a lower recursion frame that closed the cycle (i.e. a lower recursion frame
                    // that returned to the same rule at the same position) -- see where inLeftRecCycle
                    // was set, above. If inLeftRecCycle has been set to true, keep iteratively matching
                    // (growing the parse tree downwards from the current point), incorporating lower matches
                    // for this rule at this position as successively higher subtrees of the match tree,
                    // until the match can no longer be improved. 
                    if (inLeftRecCycle) {
                        // Update cycleDepth, to reduce duplicated work when two sibling or cousin clauses
                        // point to the same rule, then update cycle depth for this input position.
                        parser.cycleDepthForPos[pos]++;
                        if (Parser.DEBUG && inLeftRecCycle) {
                            System.out.println(indent + "LOOPING: " + rule + " : " + pos);
                        }
                    } else {
                        break;
                    }
                }

                // On exit from this frame of recursion, mark this rule and position as is no longer being part of
                // the recursion path. (This is paired with "inRecPath = true;" before the while loop.) 
                inRecPath = false;
            }
        } else {
            if (Parser.DEBUG) {
                System.out.println(indent + "Using memo: "
                        + (match == Match.MISMATCH ? rule + " : " + pos + " => MISMATCH" : match));
            }
        }
        if (Parser.DEBUG) {
            System.out.println(indent + "Exiting recursion: "
                    + (match == Match.MISMATCH ? rule + " : " + pos + " => MISMATCH" : match));
        }

        // Return the best match so far (match will be non-null at this point)
        return match;
    }
}
