package com.squirrelparser;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Optional;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Combinators.ZeroOrMore;

/**
 * Shared helper functions for all test files.
 * Port of test_utils.dart from Dart implementation.
 */
public class TestUtils {

    /**
     * Parse result tuple: (success, errorCount, skippedStrings)
     */
    public record ParseResult(boolean success, int errorCount, List<String> skipped) {}

    /**
     * Parse input with error recovery and return (success, errorCount, skipped).
     * topRule defaults to 'S' for backward compatibility.
     */
    public static ParseResult parse(Map<String, Clause> rules, String input) {
        return parse(rules, input, "S");
    }

    /**
     * Parse input with error recovery and return (success, errorCount, skipped).
     *
     * Result always spans input with new invariant.
     * Check if the entire result is just a SyntaxError (total failure).
     */
    public static ParseResult parse(Map<String, Clause> rules, String input, String topRule) {
        var parser = new Parser(rules, input);
        var result = parser.parse(topRule);

        // Result always spans input with new invariant.
        // Check if the entire result is just a SyntaxError (total failure)
        if (result instanceof SyntaxError err) {
            return new ParseResult(false, 1, List.of(err.skipped()));
        }

        return new ParseResult(true, countErrors(result), getSkippedStrings(result));
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
     * Count deletions in parse tree.
     */
    public static int countDeletions(MatchResult result) {
        if (result == null || result.isMismatch()) {
            return 0;
        }
        int count = (result instanceof SyntaxError && ((SyntaxError) result).isDeletion()) ? 1 : 0;
        for (var child : result.subClauseMatches()) {
            count += countDeletions(child);
        }
        return count;
    }

    /**
     * Get list of skipped strings from syntax errors.
     */
    public static List<String> getSkippedStrings(MatchResult result) {
        var skipped = new ArrayList<String>();
        collectSkipped(result, skipped);
        return skipped;
    }

    private static void collectSkipped(MatchResult result, List<String> skipped) {
        if (result == null || result.isMismatch()) {
            return;
        }
        if (result instanceof SyntaxError err && !err.isDeletion()) {
            skipped.add(err.skipped());
        }
        for (var child : result.subClauseMatches()) {
            collectSkipped(child, skipped);
        }
    }

    /**
     * Parse and return the MatchResult directly for tree structure verification.
     * topRule defaults to 'S' for backward compatibility.
     */
    public static MatchResult parseForTree(Map<String, Clause> rules, String input) {
        return parseForTree(rules, input, "S");
    }

    /**
     * Parse and return the MatchResult directly for tree structure verification.
     *
     * With new invariant, parse() always returns a MatchResult spanning input.
     * Return null only if the entire result is a SyntaxError (total failure).
     */
    public static MatchResult parseForTree(Map<String, Clause> rules, String input, String topRule) {
        var parser = new Parser(rules, input);
        var result = parser.parse(topRule);
        // With new invariant, parse() always returns a MatchResult spanning input
        // Return null only if entire result is a SyntaxError (total failure)
        if (result instanceof SyntaxError) {
            return null;
        }
        return result;
    }

    /**
     * Debug: print tree structure
     */
    public static void printTree(MatchResult result) {
        printTree(result, 0);
    }

    private static void printTree(MatchResult result, int indent) {
        if (result == null) {
            System.out.println(" ".repeat(indent) + "null");
            return;
        }
        var prefix = " ".repeat(indent);
        var clause = result.clause();
        String clauseInfo = clause != null ? clause.getClass().getSimpleName() : "null";
        if (clause instanceof Ref ref) {
            clauseInfo = "Ref(" + ref.ruleName() + ")";
        } else if (clause instanceof com.squirrelparser.Terminals.Str str) {
            clauseInfo = "Str(\"" + str.text() + "\")";
        } else if (clause instanceof com.squirrelparser.Terminals.CharRange cr) {
            clauseInfo = "CharRange(" + cr.lo() + "-" + cr.hi() + ")";
        }
        System.out.println(prefix + clauseInfo + " pos=" + result.pos() + " len=" + result.len());
        for (var child : result.subClauseMatches()) {
            if (!child.isMismatch()) {
                printTree(child, indent + 2);
            }
        }
    }

    /**
     * Get a simplified tree representation showing rule structure.
     * Returns a string like "E(E(E(n),+n),+n)" for left-associative parse.
     */
    public static String getTreeShape(MatchResult result, Map<String, Clause> rules) {
        if (result == null || result.isMismatch()) {
            return "MISMATCH";
        }
        return buildTreeShape(result, rules);
    }

    private static String buildTreeShape(MatchResult result, Map<String, Clause> rules) {
        var clause = result.clause();

        // For Ref clauses, show the rule name and recurse into the referenced match
        if (clause instanceof Ref ref) {
            var children = result.subClauseMatches();
            if (children.isEmpty()) {
                return ref.ruleName();
            }
            // Get the shape of what the ref matched
            var childShapes = children.stream()
                .filter(c -> !c.isMismatch())
                .map(c -> buildTreeShape(c, rules))
                .toList();
            if (childShapes.isEmpty()) {
                return ref.ruleName();
            }
            if (childShapes.size() == 1) {
                return ref.ruleName() + "(" + childShapes.get(0) + ")";
            }
            return ref.ruleName() + "(" + String.join(",", childShapes) + ")";
        }

        // For Str terminals, show the matched string in quotes
        if (clause instanceof com.squirrelparser.Terminals.Str str) {
            return "'" + str.text() + "'";
        }

        // For Char terminals, show the character
        if (clause instanceof com.squirrelparser.Terminals.Char ch) {
            return "'" + ch.ch() + "'";
        }

        // For CharRange terminals, show the range
        if (clause instanceof com.squirrelparser.Terminals.CharRange cr) {
            return "[" + cr.lo() + "-" + cr.hi() + "]";
        }

        // For Seq, First, show children
        if (clause instanceof Seq || clause instanceof First) {
            var children = result.subClauseMatches().stream()
                .filter(c -> !c.isMismatch())
                .map(c -> buildTreeShape(c, rules))
                .toList();
            if (children.isEmpty()) {
                return "()";
            }
            if (children.size() == 1) {
                return children.get(0);
            }
            return "(" + String.join(",", children) + ")";
        }

        // For repetition operators
        if (clause instanceof OneOrMore || clause instanceof ZeroOrMore) {
            var children = result.subClauseMatches().stream()
                .filter(c -> !c.isMismatch())
                .map(c -> buildTreeShape(c, rules))
                .toList();
            if (children.isEmpty()) {
                return "[]";
            }
            return "[" + String.join(",", children) + "]";
        }

        // For Optional
        if (clause instanceof Optional) {
            var children = result.subClauseMatches().stream()
                .filter(c -> !c.isMismatch())
                .map(c -> buildTreeShape(c, rules))
                .toList();
            if (children.isEmpty()) {
                return "?()";
            }
            return "?(" + String.join(",", children) + ")";
        }

        // Default: show clause type
        return clause != null ? clause.getClass().getSimpleName() : "null";
    }

    /**
     * Check if tree has left-associative BINDING (not just left-recursive structure).
     *
     * For true left-associativity like ((0+1)+2):
     * - The LEFT child E should itself be a recursive application (E op X), not just base case
     * - This means the left E's first child is also an E
     *
     * For right-associative binding like 0+(1+2) from ambiguous grammar:
     * - The LEFT child E is just the base case (no E child)
     * - The RIGHT child E does all the work
     */
    public static boolean isLeftAssociative(MatchResult result, String ruleName) {
        if (result == null || result.isMismatch()) {
            return false;
        }

        // Find all instances of the rule in the tree
        var instances = findRuleInstances(result, ruleName);
        if (instances.size() < 2) {
            return false;
        }

        // For left-associativity, check if ANY instance's LEFT CHILD E
        // is itself an application of the recursive pattern (not just base case)
        for (var instance : instances) {
            var firstChild = getFirstSemanticChild(instance, ruleName);
            if (!firstChild.isSameRule || firstChild.child == null) {
                continue;
            }

            // Now check if this first_child E is itself recursive (not just base case)
            // A recursive E will have another E as its first child
            var nestedFirst = getFirstSemanticChild(firstChild.child, ruleName);
            if (nestedFirst.isSameRule) {
                // The left E has another E as its first child -> truly left-associative
                return true;
            }
        }

        return false;
    }

    private record FirstChildResult(MatchResult child, boolean isSameRule) {}

    /**
     * Get the first semantic child of a result, drilling through Seq/First wrappers.
     * Returns (child, isSameRule) where isSameRule indicates if child is Ref(ruleName).
     */
    private static FirstChildResult getFirstSemanticChild(MatchResult result, String ruleName) {
        var children = result.subClauseMatches().stream()
            .filter(c -> !c.isMismatch())
            .toList();
        if (children.isEmpty()) {
            return new FirstChildResult(null, false);
        }

        var firstChild = children.get(0);

        // Drill through Seq/First to find actual first element
        while (firstChild.clause() instanceof Seq || firstChild.clause() instanceof First) {
            var innerChildren = firstChild.subClauseMatches().stream()
                .filter(c -> !c.isMismatch())
                .toList();
            if (innerChildren.isEmpty()) {
                return new FirstChildResult(null, false);
            }
            firstChild = innerChildren.get(0);
        }

        boolean isSameRule = firstChild.clause() instanceof Ref ref && ref.ruleName().equals(ruleName);
        return new FirstChildResult(firstChild, isSameRule);
    }

    /**
     * Find all MatchResults where clause is Ref(ruleName)
     */
    private static List<MatchResult> findRuleInstances(MatchResult result, String ruleName) {
        var instances = new ArrayList<MatchResult>();

        if (result.clause() instanceof Ref ref && ref.ruleName().equals(ruleName)) {
            instances.add(result);
        }

        for (var child : result.subClauseMatches()) {
            if (!child.isMismatch()) {
                instances.addAll(findRuleInstances(child, ruleName));
            }
        }

        return instances;
    }

    /**
     * Count the total occurrences of a rule in the parse tree.
     */
    public static int countRuleDepth(MatchResult result, String ruleName) {
        if (result == null || result.isMismatch()) {
            return 0;
        }
        return countDepthHelper(result, ruleName);
    }

    private static int countDepthHelper(MatchResult result, String ruleName) {
        var clause = result.clause();
        int count = 0;

        if (clause instanceof Ref ref && ref.ruleName().equals(ruleName)) {
            count = 1;
        }

        // Recurse into ALL children to find all occurrences
        for (var child : result.subClauseMatches()) {
            if (!child.isMismatch()) {
                count += countDepthHelper(child, ruleName);
            }
        }

        return count;
    }

    /**
     * Verify that for input with N operators, we have N+1 base terms and N operator applications.
     * For "n+n+n" we expect 3 'n' terms and 2 '+n' applications in a left-assoc tree.
     */
    public static boolean verifyOperatorCount(MatchResult result, String opStr, int expectedOps) {
        if (result == null || result.isMismatch()) {
            return false;
        }
        int count = countOperators(result, opStr);
        return count == expectedOps;
    }

    private static int countOperators(MatchResult result, String opStr) {
        int count = 0;
        if (result.clause() instanceof com.squirrelparser.Terminals.Str str && str.text().equals(opStr)) {
            count = 1;
        }
        for (var child : result.subClauseMatches()) {
            if (!child.isMismatch()) {
                count += countOperators(child, opStr);
            }
        }
        return count;
    }
}
