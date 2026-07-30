package com.squirrelparser.clause.nonterminal;

import static com.squirrelparser.parser.MatchResult.mismatch;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.clause.terminal.Str;
import com.squirrelparser.parser.Match;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.Parser;
import com.squirrelparser.parser.ParserStats;
import com.squirrelparser.parser.SyntaxError;

/**
 * Sequence: matches all sub-clauses in order, with error recovery.
 */
public final class Seq extends HasMultipleSubClauses {
    public Seq(List<Clause> subClauses) {
        super(subClauses);
    }

    /**
     * Find the first meaningful bound among remaining siblings.
     * Skips over transparent rules (marked with ~) since they don't produce AST nodes
     * and shouldn't be used as structural boundaries.
     */
    private Clause findMeaningfulBound(int startIdx, Parser parser) {
        for (int j = startIdx; j < subClauses.size(); j++) {
            Clause clause = subClauses.get(j);

            // Check if this clause is a Ref to a transparent rule
            if (clause instanceof Ref ref && parser.transparentRules().contains(ref.ruleName())) {
                continue;
            }

            // Found a non-transparent clause - use as bound
            return clause;
        }
        return null;
    }

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        List<MatchResult> children = new ArrayList<>();
        int curr = pos;
        int i = 0;

        while (i < subClauses.size()) {
            Clause clause = subClauses.get(i);
            // Find meaningful bound by looking past transparent rules
            Clause siblingBound = findMeaningfulBound(i + 1, parser);
            Clause effectiveBound = (parser.inRecoveryPhase() && siblingBound != null) ? siblingBound : bound;
            MatchResult result = parser.match(clause, curr, effectiveBound);

            if (result.isMismatch()) {
                if (parser.inRecoveryPhase() && !result.isFromLRContext()) {
                    var recovery = recover(parser, curr, i);
                    if (recovery != null) {
                        ParserStats.recordRecovery();
                        int inputSkip = recovery.inputSkip;
                        int grammarSkip = recovery.grammarSkip;
                        MatchResult probe = recovery.probe;

                        if (inputSkip > 0) {
                            children.add(new SyntaxError(curr, inputSkip));
                        }

                        for (int j = 0; j < grammarSkip; j++) {
                            children.add(new SyntaxError(curr + inputSkip, 0, subClauses.get(i + j)));
                        }

                        if (probe == null) {
                            curr += inputSkip;
                            break;
                        }

                        children.add(probe);
                        curr += inputSkip + probe.len();
                        i += grammarSkip + 1;
                        continue;
                    }
                }
                return mismatch();
            }

            children.add(result);
            curr += result.len();
            i++;
        }

        if (children.isEmpty()) {
            return new Match(this, pos, 0);
        }

        return Match.withChildren(this, children, allComplete(children));
    }

    private record Recovery(int inputSkip, int grammarSkip, MatchResult probe) {}

    /**
     * Attempt to recover from a mismatch.
     *
     * Key constraint (C16 - First Element Anchor): When the FIRST element of a
     * sequence fails to match, we should NOT skip input to "find" it elsewhere.
     * The first element is an anchor that defines the start of this construct.
     * If it's missing, this isn't a recoverable error within this sequence -
     * the parent should handle recovery instead.
     */
    private Recovery recover(Parser parser, int curr, int i) {
        // C16: Don't skip input to find the first element - it's an anchor
        if (i == 0) {
            // If we're at end of input, allow grammar element deletion
            if (curr >= parser.input().length()) {
                return new Recovery(0, subClauses.size(), null);
            }
            return null; // First element must match at current position
        }

        int maxScan = parser.input().length() - curr + 1;
        int maxGrammar = subClauses.size() - i;

        for (int inputSkip = 0; inputSkip < maxScan; inputSkip++) {
            int probePos = curr + inputSkip;

            if (probePos >= parser.input().length()) {
                if (inputSkip == 0) {
                    return new Recovery(inputSkip, maxGrammar, null);
                }
                continue;
            }

            for (int grammarSkip = 0; grammarSkip < maxGrammar; grammarSkip++) {
                if ((grammarSkip == 0 && inputSkip == 0) || (grammarSkip > 0)) {
                    continue;
                }

                int clauseIdx = i + grammarSkip;
                Clause clause = subClauses.get(clauseIdx);

                Clause failedClause = subClauses.get(i);
                if (failedClause instanceof Str str && str.text().length() == 1 && inputSkip > 1) {
                    if (clauseIdx + 1 < subClauses.size()) {
                        Clause nextClause = subClauses.get(clauseIdx + 1);
                        if (nextClause instanceof Str nextStr) {
                            String skipped = parser.input().substring(curr, curr + inputSkip);
                            if (skipped.contains(nextStr.text())) {
                                continue;
                            }
                        }
                    }
                }
                MatchResult probe = parser.probe(clause, probePos);
                if (!probe.isMismatch()) {
                    if (clause instanceof Str str && inputSkip > str.text().length()) {
                        if (str.text().length() > 1) {
                            continue;
                        }
                        String skipped = parser.input().substring(curr, curr + inputSkip);
                        if (skipped.contains(str.text())) {
                            continue;
                        }
                    }
                    return new Recovery(inputSkip, grammarSkip, probe);
                }
            }
        }
        return null;
    }

    private static boolean allComplete(List<MatchResult> children) {
        return children.stream().allMatch(c -> c.isMismatch() || c.isComplete());
    }

    @Override
    public String toString() {
        return "(" + subClauses.stream().map(Object::toString).collect(Collectors.joining(" ")) + ")";
    }
}
