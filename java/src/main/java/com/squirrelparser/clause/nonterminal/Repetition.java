package com.squirrelparser.clause.nonterminal;

import static com.squirrelparser.parser.MatchResult.mismatch;

import java.util.ArrayList;
import java.util.List;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.clause.terminal.AnyChar;
import com.squirrelparser.clause.terminal.Char;
import com.squirrelparser.clause.terminal.CharSet;
import com.squirrelparser.parser.Match;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.Parser;
import com.squirrelparser.parser.ParserStats;
import com.squirrelparser.parser.SyntaxError;

/**
 * Base class for repetition (OneOrMore, ZeroOrMore).
 */
public sealed class Repetition extends HasOneSubClause permits OneOrMore, ZeroOrMore {
    private final boolean requireOne;

    protected Repetition(Clause subClause, boolean requireOne) {
        super(subClause);
        this.requireOne = requireOne;
    }

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        List<MatchResult> children = new ArrayList<>();
        int curr = pos;
        boolean incomplete = false;

        while (curr <= parser.input().length()) {
            if (parser.inRecoveryPhase() && bound != null) {
                if (parser.canMatchNonzeroAt(bound, curr)) {
                    break;
                }
            }

            MatchResult result = parser.match(subClause, curr);
            if (result.isMismatch()) {
                if (!parser.inRecoveryPhase() && curr < parser.input().length()) {
                    incomplete = true;
                }

                if (parser.inRecoveryPhase()) {
                    // Only pass hasValidMatch=true if we have at least one non-error child.
                    boolean hasValidMatch = children.stream().anyMatch(c -> !(c instanceof SyntaxError));
                    var recovery = recover(parser, curr, hasValidMatch, bound);
                    if (recovery != null) {
                        ParserStats.recordRecovery();
                        int skip = recovery.skip;
                        MatchResult probe = recovery.probe;
                        children.add(new SyntaxError(curr, skip));
                        if (probe != null) {
                            children.add(probe);
                            curr += skip + probe.len();
                            continue;
                        } else {
                            curr += skip;
                            break;
                        }
                    }
                }
                break;
            }
            if (result.len() == 0) {
                break;
            }
            children.add(result);
            curr += result.len();
        }
        if (requireOne && children.isEmpty()) {
            return mismatch();
        }
        if (children.isEmpty()) {
            return new Match(this, pos, 0, List.of(), !incomplete, false, 0);
        }
        return Match.withChildren(this, children, !incomplete && allComplete(children));
    }

    private record RepetitionRecovery(int skip, MatchResult probe) {}

    /**
     * Attempt recovery within repetition.
     *
     * Key principle: Repetitions only do recovery for COMPLEX subClauses (Seq, First, Ref).
     * For character-level terminals (CharSet, Char, AnyChar), the repetition should NOT
     * try to extend itself by skipping over errors. Instead, return what we have and
     * let the parent Seq handle errors with better structural context.
     *
     * @param hasValidMatch indicates if we've already matched at least one valid element.
     * @param bound is the next sibling clause that must not be skipped over.
     */
    private RepetitionRecovery recover(Parser parser, int curr, boolean hasValidMatch, Clause bound) {
        // For character-level terminals, don't do repetition recovery.
        if (subClause instanceof CharSet || subClause instanceof Char || subClause instanceof AnyChar) {
            return null;
        }

        // Scan for more matches
        for (int skip = 1; skip < parser.input().length() - curr + 1; skip++) {
            int probePos = curr + skip;

            // Don't skip past the bound - let parent Seq handle recovery there
            if (bound != null && parser.canMatchNonzeroAt(bound, probePos)) {
                break;
            }

            // Use match to allow internal recovery within complex subClauses.
            MatchResult probe = parser.match(subClause, probePos);
            if (!probe.isMismatch() && probe.len() > 0) {
                return new RepetitionRecovery(skip, probe);
            }
        }

        // No more matches found.
        // Only skip remaining as error if we already have valid matches
        // (otherwise OneOrMore would incorrectly succeed with just errors).
        // But don't skip past the bound!
        if (hasValidMatch && curr < parser.input().length()) {
            int skipToEnd = parser.input().length() - curr;
            // Check if bound matches anywhere before end of input
            if (bound != null) {
                for (int skip = 1; skip <= skipToEnd; skip++) {
                    if (parser.canMatchNonzeroAt(bound, curr + skip)) {
                        // Bound matches at this position - only skip up to here
                        if (skip > 0) {
                            return new RepetitionRecovery(skip, null);
                        }
                        return null; // Can't skip anything without hitting bound
                    }
                }
            }
            return new RepetitionRecovery(skipToEnd, null);
        }
        return null;
    }

    private static boolean allComplete(List<MatchResult> children) {
        return children.stream().allMatch(c -> c.isMismatch() || c.isComplete());
    }
}
