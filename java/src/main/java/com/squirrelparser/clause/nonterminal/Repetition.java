package com.squirrelparser.clause.nonterminal;

import static com.squirrelparser.parser.MatchResult.mismatch;

import java.util.ArrayList;
import java.util.List;

import com.squirrelparser.clause.Clause;
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
        boolean hasRecovered = false;

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
                    var recovery = recover(parser, curr, hasRecovered);
                    if (recovery != null) {
                        ParserStats.recordRecovery();
                        int skip = recovery.skip;
                        MatchResult probe = recovery.probe;
                        children.add(new SyntaxError(curr, skip));
                        hasRecovered = true;
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

    private RepetitionRecovery recover(Parser parser, int curr, boolean hasRecovered) {
        for (int skip = 1; skip < parser.input().length() - curr + 1; skip++) {
            MatchResult probe = parser.probe(subClause, curr + skip);
            if (!probe.isMismatch()) {
                return new RepetitionRecovery(skip, probe);
            }
        }
        if (hasRecovered && curr < parser.input().length()) {
            int skipToEnd = parser.input().length() - curr;
            return new RepetitionRecovery(skipToEnd, null);
        }
        return null;
    }

    private static boolean allComplete(List<MatchResult> children) {
        return children.stream().allMatch(c -> c.isMismatch() || c.isComplete());
    }
}
