package com.squirrelparser;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import static com.squirrelparser.MatchResult.mismatch;

/**
 * Helper: check if all children are complete.
 */
final class CombinatorHelper {
    static boolean allComplete(List<MatchResult> children) {
        return children.stream().allMatch(c -> c.isMismatch() || c.isComplete());
    }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Sequence: matches all sub-clauses in order, with error recovery.
 */
final class Seq extends HasMultipleSubClauses {
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

        return Match.withChildren(this, children, CombinatorHelper.allComplete(children));
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
                if (grammarSkip == 0 && inputSkip == 0) continue;
                if (grammarSkip > 0) continue;

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

    @Override
    public String toString() {
        return "(" + subClauses.stream().map(Object::toString).collect(Collectors.joining(" ")) + ")";
    }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Ordered choice: matches the first successful sub-clause.
 */
final class First extends HasMultipleSubClauses {
    public First(List<Clause> subClauses) {
        super(subClauses);
    }

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        for (int i = 0; i < subClauses.size(); i++) {
            MatchResult result = parser.match(subClauses.get(i), pos, bound);
            if (!result.isMismatch()) {
                if (parser.inRecoveryPhase() && i == 0 && result.totDescendantErrors() > 0) {
                    MatchResult bestResult = result;
                    int bestLen = result.len();
                    int bestErrors = result.totDescendantErrors();

                    for (int j = 1; j < subClauses.size(); j++) {
                        MatchResult altResult = parser.match(subClauses.get(j), pos, bound);
                        if (!altResult.isMismatch()) {
                            int altLen = altResult.len();
                            int altErrors = altResult.totDescendantErrors();

                            double bestErrorRate = bestLen > 0 ? (double) bestErrors / bestLen : 0.0;
                            double altErrorRate = altLen > 0 ? (double) altErrors / altLen : 0.0;
                            double errorRateThreshold = 0.5;

                            if ((bestErrorRate >= errorRateThreshold && altErrorRate < errorRateThreshold) ||
                                altLen > bestLen ||
                                (altLen == bestLen && altErrors < bestErrors)) {
                                bestResult = altResult;
                                bestLen = altLen;
                                bestErrors = altErrors;
                            }
                            if (altErrors == 0 && altLen >= bestLen) break;
                        }
                    }
                    return Match.withChildren(this, List.of(bestResult), bestResult.isComplete());
                }
                return Match.withChildren(this, List.of(result), result.isComplete());
            }
        }
        return mismatch();
    }

    @Override
    public String toString() {
        return "(" + subClauses.stream().map(Object::toString).collect(Collectors.joining(" / ")) + ")";
    }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Base class for repetition (OneOrMore, ZeroOrMore).
 */
sealed class Repetition extends HasOneSubClause permits OneOrMore, ZeroOrMore {
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
            if (result.len() == 0) break;
            children.add(result);
            curr += result.len();
        }
        if (requireOne && children.isEmpty()) {
            return mismatch();
        }
        if (children.isEmpty()) {
            return new Match(this, pos, 0, List.of(), !incomplete, false, 0);
        }
        return Match.withChildren(this, children, !incomplete && CombinatorHelper.allComplete(children));
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
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * One or more repetitions.
 */
final class OneOrMore extends Repetition {
    public OneOrMore(Clause subClause) {
        super(subClause, true);
    }

    @Override
    public String toString() {
        return subClause + "+";
    }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Zero or more repetitions.
 */
final class ZeroOrMore extends Repetition {
    public ZeroOrMore(Clause subClause) {
        super(subClause, false);
    }

    @Override
    public String toString() {
        return subClause + "*";
    }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Optional: matches zero or one instance.
 */
final class Optional extends HasOneSubClause {
    public Optional(Clause subClause) {
        super(subClause);
    }

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        MatchResult result = parser.match(subClause, pos, bound);

        if (result.isMismatch()) {
            boolean incomplete = !parser.inRecoveryPhase() && pos < parser.input().length();
            return new Match(this, pos, 0, List.of(), !incomplete, false, 0);
        }

        return Match.withChildren(this, List.of(result), result.isComplete());
    }

    @Override
    public String toString() {
        return subClause + "?";
    }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Reference to a named rule.
 */
final class Ref extends Clause {
    private final String ruleName;

    public Ref(String ruleName) {
        this.ruleName = ruleName;
    }

    public String ruleName() {
        return ruleName;
    }

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        Clause clause = parser.rules().get(ruleName);
        if (clause == null) {
            throw new IllegalArgumentException("Rule \"" + ruleName + "\" not found");
        }
        MatchResult result = parser.match(clause, pos, bound);
        if (result.isMismatch()) return result;
        return Match.withChildren(this, List.of(result), result.isComplete());
    }

    @Override
    public void checkRuleRefs(Map<String, Clause> grammarMap) {
        if (!grammarMap.containsKey(ruleName) && !grammarMap.containsKey("~" + ruleName)) {
            throw new IllegalArgumentException("Rule \"" + ruleName + "\" not found in grammar");
        }
    }

    @Override
    public String toString() {
        return ruleName;
    }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Negative lookahead: succeeds if sub-clause fails, consumes nothing.
 */
final class NotFollowedBy extends HasOneSubClause {
    public NotFollowedBy(Clause subClause) {
        super(subClause);
    }

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        MatchResult result = parser.match(subClause, pos, bound);
        return result.isMismatch() ? new Match(this, pos, 0) : mismatch();
    }

    @Override
    public String toString() {
        return "!" + subClause;
    }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Positive lookahead: succeeds if sub-clause succeeds, consumes nothing.
 */
final class FollowedBy extends HasOneSubClause {
    public FollowedBy(Clause subClause) {
        super(subClause);
    }

    @Override
    public MatchResult match(Parser parser, int pos, Clause bound) {
        MatchResult result = parser.match(subClause, pos, bound);
        return result.isMismatch() ? mismatch() : new Match(this, pos, 0);
    }

    @Override
    public String toString() {
        return "&" + subClause;
    }
}
