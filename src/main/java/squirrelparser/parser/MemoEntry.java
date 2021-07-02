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

    /** The number of left recursive cycles that had been expanded when this memo entry was last read. */
    private int cycleDepth;

    /** Parse a rule while handling left recursion. */
    Match match(Parser parser, Clause rule, int pos) {
        var indent = Parser.DEBUG ? "|   ".repeat(parser.recursionDepth - 1) : null;
        if (Parser.DEBUG) {
            System.out.println(indent + "Entering: " + rule + " : " + pos);
        }
        // Checking whether the cycle depth of a memo entry is the same as the cycle depth for the
        // current position serves several purposes:
        // (1) It ensures that the existence of an older memo in the memo table does not prevent the
        //     evaluation of the same rule in the next-higher expansion of a left-recursive cycle.
        // (2) It ensures that a rule is evaluated at most once in the current expansion of a
        //     left-recursive cycle (if the same rule is encountered at the same position in the
        //     recursion path, then the memo table must be used for the lower instance).
        // (3) It ensures that "cousin" RuleRefs (where a reference to the same rule is used in
        //     more than one subclause of the same rule) are evaluated only once, to avoid
        //     duplicating work.
        // (4) When referring to subclauses to the right of the current position, the subclause's
        //     own cycleDepthForPos will be checked, which will ensure that if the memo for the
        //     subclause is non-null and has the latest cycle depth for that position, the memo
        //     will be returned, rather than repeating the work. In other words, if an attempt
        //     is made to match a rule more than once during the same iteration of left recursion
        //     expansion, then the second and subsequent attempt will read straight from the
        //     memo table.
        if (match == null || cycleDepth < parser.cycleDepthForPos[pos]) {
            // This memo entry contains a match from a previous expansion of left recursion
            // (i.e. with a smaller cycle depth than the current cycle depth), or there is
            // no match for this memo entry yet.
            if (inRecPath) {
                // We reached a cycle in the recursion path.
                if (Parser.DEBUG) {
                    System.out.println(indent + "In rec path for: " + rule + " : " + pos);
                }
                if (match == null) {
                    if (Parser.DEBUG) {
                        System.out.println(indent + "Seed match: " + rule + " : " + pos + " => MISMATCH");
                    }
                    // If we encountered the same rule and position twice in the recursion path, and
                    // there is not yet a memo entry in the memo table, then we hit a left-recursive
                    // cycle for the first time.
                    // Mark this memo entry as being the "head node" in the left recursive cycle.
                    // This effectively passes a message back up to the ancestral node with the same
                    // rule and position to tell it to start iteratively growing the left-recursive
                    // subtree of the parse tree.
                    // Once a rule has been marked for left recursion expansion in a given position,
                    // it will always be marked. This is important in the case of multiple interlocked
                    // left recursion cycles, e.g. the "Interlocking cycles" examples given here:
                    // https://github.com/PhilippeSigaud/Pegged/wiki/Left-Recursion
                    inLeftRecCycle = true;
                    // When a left-recursive cycle is first found, the bottom-most node in the parse
                    // tree corresponding to this clause at this position must be marked as a mismatch.
                    // (This is the fixed point of the left recursive cycle.)
                    match = Match.MISMATCH;
                } else {
                    if (Parser.DEBUG) {
                        System.out.println(indent + "Using memo: "
                                + (match == Match.MISMATCH ? rule + " : " + pos + " => MISMATCH" : match));
                    }
                    // Otherwise if we reached the same clause twice on the recursion path, but there's
                    // already a memo in the memo table for this clause. This must be a match from a
                    // lower expansion of a left-recursive cycle. fall through, and return the match
                    // from the memo table.
                }
            } else {
                // No left recursive cycle has yet been found in the recursion path.
                if (Parser.DEBUG) {
                    System.out.println(indent + "Not in rec path for: " + rule + " : " + pos);
                }

                // Mark this rule and position as being in the recursion path.
                inRecPath = true;

                // Left recursion expansion loop (executes only once if no left recursive cycle is encountered).
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
                    if (!inLeftRecCycle) {
                        break;
                    }

                    // Increment cycleDepthForPos[pos], and update cycleDepth of the new match
                    cycleDepth = ++(parser.cycleDepthForPos[pos]);
                    if (Parser.DEBUG) {
                        System.out.println(indent + "LOOPING: " + rule + " : " + pos);
                    }
                }

                // On exit from this frame of recursion, mark this rule and position as is no longer being part of
                // the recursion path. (This is paired with "inRecPath = true;" before the while loop.)
                inRecPath = false;
            }

            // Update cycleDepth when a memo entry is read, whether or not the match improved,
            // to avoid duplicating work in "cousin clauses" (where the same RuleRef occurs
            // multiple times within the clause tree of a single rule). This "upgrades" the
            // cycleDepth of the match or mismatch, in keeping with the logic that a memo should
            // only be updated if the match gets longer -- i.e. once a clause goes from matching
            // to mismatching, its longest match is always considered the current best match.
            cycleDepth = parser.cycleDepthForPos[pos];

        } else {
            // There is a match already in this memo entry, and the match is for the same cycle depth.
            // Fall through, and just return the current memo entry.
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
