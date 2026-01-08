package com.squirrelparser;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Combinator clause implementations (combine multiple clauses).
 */
public final class Combinators {

    private Combinators() {} // Prevent instantiation

    private static boolean allComplete(List<MatchResult> children) {
        return children.stream().allMatch(r -> r.isMismatch() || r.isComplete());
    }

    /**
     * Count total syntax errors in a parse tree.
     */
    public static int countErrors(MatchResult result) {
        if (result == null || result.isMismatch()) {
            return 0;
        }
        int count = (result instanceof SyntaxError) ? 1 : 0;
        for (var child : result.subClauseMatches()) {
            count += countErrors(child);
        }
        return count;
    }

    /**
     * Get all syntax errors from parse tree.
     *
     * The parse tree is expected to span the entire input (invariant from Parser.parse()).
     * All syntax errors are already embedded in the tree as SyntaxError nodes.
     */
    public static List<SyntaxError> getSyntaxErrors(MatchResult result, String input) {
        var syntaxErrors = new ArrayList<SyntaxError>();

        // Recursive collector - traverse tree and collect all SyntaxError nodes
        java.util.function.Consumer<MatchResult> collect = new java.util.function.Consumer<MatchResult>() {
            @Override
            public void accept(MatchResult r) {
                if (r.isMismatch()) {
                    return;
                }
                if (r instanceof SyntaxError se) {
                    syntaxErrors.add(se);
                }
                for (var child : r.subClauseMatches()) {
                    accept(child);
                }
            }
        };

        collect.accept(result);
        return syntaxErrors;
    }

    /** Sequence: matches all sub-clauses in order, with error recovery. */
    public record Seq(List<Clause> subClauses, boolean transparent) implements Clause {
        public Seq(Clause... clauses) {
            this(Arrays.asList(clauses), false);
        }

        public Seq(List<Clause> subClauses) {
            this(subClauses, false);
        }

        @Override
        public MatchResult match(Parser parser, int pos, Clause bound) {
            var children = new ArrayList<MatchResult>();
            int curr = pos;
            int i = 0;

            while (i < subClauses.size()) {
                var clause = subClauses.get(i);
                Clause next = (i + 1 < subClauses.size()) ? subClauses.get(i + 1) : null;
                Clause effectiveBound = (parser.inRecoveryPhase() && next != null) ? next : bound;
                var result = parser.match(clause, curr, effectiveBound);

                if (result.isMismatch()) {
                    if (parser.inRecoveryPhase() && !result.isFromLRContext()) {
                        var recovery = recover(parser, curr, i);
                        if (recovery != null) {
                            if (recovery.inputSkip > 0) {
                                children.add(new SyntaxError(
                                    curr,
                                    recovery.inputSkip,
                                    parser.input().substring(curr, curr + recovery.inputSkip)
                                ));
                            }

                            for (int j = 0; j < recovery.grammarSkip; j++) {
                                children.add(new SyntaxError(curr + recovery.inputSkip, 0, "", true));
                            }

                            if (recovery.probe == null) {
                                curr += recovery.inputSkip;
                                break;
                            }

                            children.add(recovery.probe);
                            curr += recovery.inputSkip + recovery.probe.len();
                            i += recovery.grammarSkip + 1;
                            continue;
                        }
                    }
                    return Mismatch.INSTANCE;
                }

                children.add(result);
                curr += result.len();
                i++;
            }

            if (children.isEmpty()) {
                return new Match(this, pos, 0, List.of(), true, false);
            }

            return new Match(this, children, allComplete(children));
        }

        private record RecoveryResult(int inputSkip, int grammarSkip, MatchResult probe) {}

        /**
         * Attempt to recover from a mismatch.
         */
        private RecoveryResult recover(Parser parser, int curr, int i) {
            int maxScan = parser.input().length() - curr + 1;
            int maxGrammar = subClauses.size() - i;

            for (int inputSkip = 0; inputSkip < maxScan; inputSkip++) {
                int probePos = curr + inputSkip;

                if (probePos >= parser.input().length()) {
                    if (inputSkip == 0) {
                        // EOF: deleting remaining grammar elements
                        return new RecoveryResult(inputSkip, maxGrammar, null);
                    }
                    continue;
                }

                for (int grammarSkip = 0; grammarSkip < maxGrammar; grammarSkip++) {
                    if ((grammarSkip == 0 && inputSkip == 0) || (grammarSkip > 0)) {
                        continue;
                    }

                    int clauseIdx = i + grammarSkip;
                    var clause = subClauses.get(clauseIdx);

                    var failedClause = subClauses.get(i);
                    if (failedClause instanceof Terminals.Str str &&
                        str.text().length() == 1 &&
                        inputSkip > 1) {
                        if (clauseIdx + 1 < subClauses.size()) {
                            var nextClause = subClauses.get(clauseIdx + 1);
                            if (nextClause instanceof Terminals.Str nextStr) {
                                String skipped = parser.input().substring(curr, curr + inputSkip);
                                if (skipped.contains(nextStr.text())) {
                                    continue;
                                }
                            }
                        }
                    }

                    var probe = parser.probe(clause, probePos);

                    if (!probe.isMismatch()) {
                        if (clause instanceof Terminals.Str str && inputSkip > str.text().length()) {
                            if (str.text().length() > 1) {
                                continue;
                            }
                            String skipped = parser.input().substring(curr, curr + inputSkip);
                            if (skipped.contains(str.text())) {
                                continue;
                            }
                        }

                        return new RecoveryResult(inputSkip, grammarSkip, probe);
                    }
                }
            }

            return null;
        }

        @Override
        public String toString() {
            return "Seq(" + subClauses + ")";
        }
    }

    /** First/Choice: tries alternatives in order, returns first match. */
    public record First(List<Clause> subClauses, boolean transparent) implements Clause {
        public First(Clause... clauses) {
            this(Arrays.asList(clauses), false);
        }

        public First(List<Clause> subClauses) {
            this(subClauses, false);
        }

        @Override
        public MatchResult match(Parser parser, int pos, Clause bound) {
            for (int i = 0; i < subClauses.size(); i++) {
                var result = parser.match(subClauses.get(i), pos, bound);
                if (!result.isMismatch()) {
                    if (parser.inRecoveryPhase() && i == 0 && countErrors(result) > 0) {
                        var bestResult = result;
                        int bestLen = result.len();
                        int bestErrors = countErrors(result);

                        for (int j = 1; j < subClauses.size(); j++) {
                            var altResult = parser.match(subClauses.get(j), pos, bound);
                            if (!altResult.isMismatch()) {
                                int altLen = altResult.len();
                                int altErrors = countErrors(altResult);

                                double bestErrorRate = bestLen > 0 ? (double) bestErrors / bestLen : 0.0;
                                double altErrorRate = altLen > 0 ? (double) altErrors / altLen : 0.0;
                                double errorRateThreshold = 0.5;

                                boolean shouldSwitch = false;

                                if (bestErrorRate >= errorRateThreshold && altErrorRate < errorRateThreshold) {
                                    shouldSwitch = true;
                                } else if (altLen > bestLen) {
                                    shouldSwitch = true;
                                } else if (altLen == bestLen && altErrors < bestErrors) {
                                    shouldSwitch = true;
                                }

                                if (shouldSwitch) {
                                    bestResult = altResult;
                                    bestLen = altLen;
                                    bestErrors = altErrors;
                                }

                                if (altErrors == 0 && altLen >= bestLen) {
                                    break;
                                }
                            }
                        }

                        return new Match(this, pos, bestLen,
                            List.of(bestResult), bestResult.isComplete(), bestResult.isFromLRContext());
                    }

                    return new Match(this, pos, result.len(),
                        List.of(result), result.isComplete(), result.isFromLRContext());
                }
            }
            return Mismatch.INSTANCE;
        }

        @Override
        public String toString() {
            return "First(" + subClauses + ")";
        }
    }

    /** OneOrMore: matches one or more repetitions. */
    public record OneOrMore(Clause subClause, boolean transparent) implements Clause {
        public OneOrMore(Clause subClause) {
            this(subClause, false);
        }

        @Override
        public MatchResult match(Parser parser, int pos, Clause bound) {
            var children = new ArrayList<MatchResult>();
            int curr = pos;
            boolean incomplete = false;
            boolean hasRecovered = false;

            while (curr <= parser.input().length()) {
                // Check bound
                if (parser.inRecoveryPhase() && bound != null) {
                    if (parser.canMatchNonzeroAt(bound, curr)) {
                        break;
                    }
                }

                var result = parser.match(subClause, curr, null);

                if (result.isMismatch()) {
                    if (!parser.inRecoveryPhase() && curr < parser.input().length()) {
                        incomplete = true;
                    }

                    if (parser.inRecoveryPhase()) {
                        var recovery = recover(parser, curr, hasRecovered);
                        if (recovery != null) {
                            children.add(new SyntaxError(
                                curr,
                                recovery.skip,
                                parser.input().substring(curr, curr + recovery.skip)
                            ));
                            hasRecovered = true;
                            if (recovery.probe != null) {
                                children.add(recovery.probe);
                                curr += recovery.skip + recovery.probe.len();
                                continue;
                            } else {
                                curr += recovery.skip;
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

            if (children.isEmpty()) {
                return Mismatch.INSTANCE;
            }

            return new Match(this, children, !incomplete && allComplete(children));
        }

        private record RepRecoveryResult(int skip, MatchResult probe) {}

        private RepRecoveryResult recover(Parser parser, int curr, boolean hasRecovered) {
            for (int skip = 1; skip < parser.input().length() - curr + 1; skip++) {
                var probe = parser.probe(subClause, curr + skip);
                if (!probe.isMismatch()) {
                    return new RepRecoveryResult(skip, probe);
                }
            }

            // If we've already recovered from previous errors and we're at or near
            // end of input, try to skip to end of input as a recovery
            if (hasRecovered && curr < parser.input().length()) {
                int skipToEnd = parser.input().length() - curr;
                return new RepRecoveryResult(skipToEnd, null);
            }

            return null;
        }

        @Override
        public String toString() {
            return subClause + "+";
        }
    }

    /** ZeroOrMore: matches zero or more repetitions. */
    public record ZeroOrMore(Clause subClause, boolean transparent) implements Clause {
        public ZeroOrMore(Clause subClause) {
            this(subClause, false);
        }

        @Override
        public MatchResult match(Parser parser, int pos, Clause bound) {
            var children = new ArrayList<MatchResult>();
            int curr = pos;
            boolean incomplete = false;
            boolean hasRecovered = false;

            while (curr <= parser.input().length()) {
                // Check bound
                if (parser.inRecoveryPhase() && bound != null) {
                    if (parser.canMatchNonzeroAt(bound, curr)) {
                        break;
                    }
                }

                var result = parser.match(subClause, curr, null);

                if (result.isMismatch()) {
                    if (!parser.inRecoveryPhase() && curr < parser.input().length()) {
                        incomplete = true;
                    }

                    if (parser.inRecoveryPhase()) {
                        var recovery = recover(parser, curr, hasRecovered);
                        if (recovery != null) {
                            children.add(new SyntaxError(
                                curr,
                                recovery.skip,
                                parser.input().substring(curr, curr + recovery.skip)
                            ));
                            hasRecovered = true;
                            if (recovery.probe != null) {
                                children.add(recovery.probe);
                                curr += recovery.skip + recovery.probe.len();
                                continue;
                            } else {
                                curr += recovery.skip;
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

            if (children.isEmpty()) {
                return new Match(this, pos, 0, List.of(), !incomplete, false);
            }

            return new Match(this, children, !incomplete && allComplete(children));
        }

        private record RepRecoveryResult(int skip, MatchResult probe) {}

        private RepRecoveryResult recover(Parser parser, int curr, boolean hasRecovered) {
            for (int skip = 1; skip < parser.input().length() - curr + 1; skip++) {
                var probe = parser.probe(subClause, curr + skip);
                if (!probe.isMismatch()) {
                    return new RepRecoveryResult(skip, probe);
                }
            }

            // If we've already recovered from previous errors and we're at or near
            // end of input, try to skip to end of input as a recovery
            if (hasRecovered && curr < parser.input().length()) {
                int skipToEnd = parser.input().length() - curr;
                return new RepRecoveryResult(skipToEnd, null);
            }

            return null;
        }

        @Override
        public String toString() {
            return subClause + "*";
        }
    }

    /** Optional: matches zero or one occurrence. */
    public record Optional(Clause subClause, boolean transparent) implements Clause {
        public Optional(Clause subClause) {
            this(subClause, false);
        }

        @Override
        public MatchResult match(Parser parser, int pos, Clause bound) {
            var result = parser.match(subClause, pos, bound);

            if (result.isMismatch()) {
                boolean incomplete = !parser.inRecoveryPhase() && pos < parser.input().length();
                return new Match(this, pos, 0, List.of(), !incomplete, false);
            }

            return new Match(this, pos, result.len(),
                List.of(result), result.isComplete(), result.isFromLRContext());
        }

        @Override
        public String toString() {
            return subClause + "?";
        }
    }

    /** NotFollowedBy: negative lookahead (doesn't consume input). */
    public record NotFollowedBy(Clause subClause, boolean transparent) implements Clause {
        public NotFollowedBy(Clause subClause) {
            this(subClause, false);
        }

        @Override
        public MatchResult match(Parser parser, int pos, Clause bound) {
            var result = parser.match(subClause, pos, bound);
            if (result.isMismatch()) {
                return new Match(this, pos, 0);
            }
            return Mismatch.INSTANCE;
        }

        @Override
        public String toString() {
            return "!" + subClause;
        }
    }

    /** FollowedBy: positive lookahead (doesn't consume input). */
    public record FollowedBy(Clause subClause, boolean transparent) implements Clause {
        public FollowedBy(Clause subClause) {
            this(subClause, false);
        }

        @Override
        public MatchResult match(Parser parser, int pos, Clause bound) {
            var result = parser.match(subClause, pos, bound);
            if (!result.isMismatch()) {
                return new Match(this, pos, 0);
            }
            return Mismatch.INSTANCE;
        }

        @Override
        public String toString() {
            return "&" + subClause;
        }
    }

    /** Ref: reference to a named rule (enables memoization and left-recursion handling). */
    public record Ref(String ruleName, boolean transparent) implements Clause {
        public Ref(String ruleName) {
            this(ruleName, false);
        }

        @Override
        public MatchResult match(Parser parser, int pos, Clause bound) {
            var rule = parser.rules().get(ruleName);
            if (rule == null) {
                throw new IllegalStateException("Rule not found: " + ruleName);
            }
            var result = parser.match(rule, pos, bound);
            if (result.isMismatch()) {
                return result;
            }
            return new Match(this, pos, result.len(),
                List.of(result), result.isComplete(), result.isFromLRContext());
        }

        @Override
        public String toString() {
            return ruleName;
        }
    }
}
