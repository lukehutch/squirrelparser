package com.squirrelparser;

import java.util.ArrayList;
import java.util.List;

/**
 * Test utilities for Squirrel Parser tests.
 */
public final class TestUtils {
    private TestUtils() {}

    /**
     * Result of parsing with error recovery.
     */
    public record ParseTestResult(boolean ok, int errorCount, List<String> skippedStrings) {}

    /**
     * Parse input with error recovery and return (success, errorCount, skippedStrings).
     */
    public static ParseTestResult testParse(String grammarSpec, String input) {
        return testParse(grammarSpec, input, "S");
    }

    /**
     * Parse input with error recovery and return (success, errorCount, skippedStrings).
     */
    public static ParseTestResult testParse(String grammarSpec, String input, String topRule) {
        ParseResult parseResult = SquirrelParser.squirrelParsePT(grammarSpec, topRule, input);

        MatchResult result = parseResult.root();
        boolean isCompleteFailure = result instanceof SyntaxError && result.len() == parseResult.input().length();
        boolean ok = !isCompleteFailure;

        int totErrors = result.totDescendantErrors();
        if (parseResult.unmatchedInput() != null && parseResult.unmatchedInput().pos() >= 0) {
            totErrors += 1;
        }

        List<String> skippedStrings = getSkippedStrings(List.of(result), input);
        if (parseResult.unmatchedInput() != null && parseResult.unmatchedInput().pos() >= 0) {
            SyntaxError unmatched = parseResult.unmatchedInput();
            skippedStrings.add(parseResult.input().substring(unmatched.pos(), unmatched.pos() + unmatched.len()));
        }

        return new ParseTestResult(ok, totErrors, skippedStrings);
    }

    /**
     * Collect all SyntaxError nodes from the parse tree.
     */
    public static List<SyntaxError> getSyntaxErrors(List<MatchResult> results) {
        List<SyntaxError> errors = new ArrayList<>();
        for (MatchResult result : results) {
            collectSyntaxErrors(result, errors);
        }
        return errors;
    }

    private static void collectSyntaxErrors(MatchResult result, List<SyntaxError> errors) {
        if (!result.isMismatch()) {
            if (result instanceof SyntaxError se) {
                errors.add(se);
            } else {
                for (MatchResult child : result.subClauseMatches()) {
                    collectSyntaxErrors(child, errors);
                }
            }
        }
    }

    /**
     * Count deletions in parse tree (SyntaxErrors with len == 0).
     */
    public static int countDeletions(List<MatchResult> results) {
        return (int) getSyntaxErrors(results).stream().filter(e -> e.len() == 0).count();
    }

    /**
     * Get list of skipped strings from syntax errors (SyntaxErrors with len > 0).
     */
    public static List<String> getSkippedStrings(List<MatchResult> results, String input) {
        List<String> skipped = new ArrayList<>();
        for (SyntaxError e : getSyntaxErrors(results)) {
            if (e.len() > 0) {
                skipped.add(input.substring(e.pos(), e.pos() + e.len()));
            }
        }
        return skipped;
    }

    /**
     * Parse and return the MatchResult for tree structure verification.
     * Returns null if the entire input is a SyntaxError.
     */
    public static MatchResult parseForTree(String grammarSpec, String input) {
        return parseForTree(grammarSpec, input, "S");
    }

    /**
     * Parse and return the MatchResult for tree structure verification.
     * Returns null if the entire input is a SyntaxError.
     */
    public static MatchResult parseForTree(String grammarSpec, String input, String topRule) {
        ParseResult parseResult = SquirrelParser.squirrelParsePT(grammarSpec, topRule, input);
        MatchResult result = parseResult.root();
        return result instanceof SyntaxError ? null : result;
    }

    /**
     * Count occurrences of a rule in the parse tree.
     */
    public static int countRuleDepth(MatchResult result, String ruleName) {
        if (result == null || result.isMismatch()) return 0;
        int count = 0;
        if (result.clause() instanceof Ref ref && ref.ruleName().equals(ruleName)) {
            count = 1;
        }
        for (MatchResult child : result.subClauseMatches()) {
            if (!child.isMismatch()) {
                count += countRuleDepth(child, ruleName);
            }
        }
        return count;
    }

    /**
     * Check if tree has left-associative binding for a rule.
     */
    public static boolean isLeftAssociative(MatchResult result, String ruleName) {
        if (result == null || result.isMismatch()) return false;

        List<MatchResult> instances = findRuleInstances(result, ruleName);
        if (instances.size() < 2) return false;

        for (MatchResult instance : instances) {
            FirstSemanticChildResult firstChildResult = getFirstSemanticChild(instance, ruleName);
            if (!firstChildResult.isSameRule || firstChildResult.child == null) continue;

            FirstSemanticChildResult nestedResult = getFirstSemanticChild(firstChildResult.child, ruleName);
            if (nestedResult.isSameRule) return true;
        }
        return false;
    }

    /**
     * Verify operator count in parse tree.
     */
    public static boolean verifyOperatorCount(MatchResult result, String opStr, int expectedOps) {
        if (result == null || result.isMismatch()) return false;
        return countOperators(result, opStr) == expectedOps;
    }

    private static List<MatchResult> findRuleInstances(MatchResult result, String ruleName) {
        List<MatchResult> instances = new ArrayList<>();
        if (result.clause() instanceof Ref ref && ref.ruleName().equals(ruleName)) {
            instances.add(result);
        }
        for (MatchResult child : result.subClauseMatches()) {
            if (!child.isMismatch()) {
                instances.addAll(findRuleInstances(child, ruleName));
            }
        }
        return instances;
    }

    private record FirstSemanticChildResult(MatchResult child, boolean isSameRule) {}

    private static FirstSemanticChildResult getFirstSemanticChild(MatchResult result, String ruleName) {
        List<MatchResult> children = result.subClauseMatches().stream()
            .filter(c -> !c.isMismatch())
            .toList();
        if (children.isEmpty()) return new FirstSemanticChildResult(null, false);

        MatchResult firstChild = children.get(0);
        while (firstChild.clause() instanceof Seq || firstChild.clause() instanceof First) {
            List<MatchResult> innerChildren = firstChild.subClauseMatches().stream()
                .filter(c -> !c.isMismatch())
                .toList();
            if (innerChildren.isEmpty()) return new FirstSemanticChildResult(null, false);
            firstChild = innerChildren.get(0);
        }

        boolean isSameRule = firstChild.clause() instanceof Ref ref && ref.ruleName().equals(ruleName);
        return new FirstSemanticChildResult(firstChild, isSameRule);
    }

    private static int countOperators(MatchResult result, String opStr) {
        int count = 0;
        if (result.clause() instanceof Str str && str.text().equals(opStr)) {
            count = 1;
        }
        for (MatchResult child : result.subClauseMatches()) {
            if (!child.isMismatch()) {
                count += countOperators(child, opStr);
            }
        }
        return count;
    }
}
