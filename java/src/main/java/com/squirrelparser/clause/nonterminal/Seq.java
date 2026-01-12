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

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        List<MatchResult> children = new ArrayList<>();
        int curr = pos;
        int i = 0;

        while (i < subClauses.size()) {
            Clause clause = subClauses.get(i);
            Clause next = (i + 1 < subClauses.size()) ? subClauses.get(i + 1) : null;
            Clause effectiveBound = (parser.inRecoveryPhase() && next != null) ? next : bound;
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

    private Recovery recover(Parser parser, int curr, int i) {
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
