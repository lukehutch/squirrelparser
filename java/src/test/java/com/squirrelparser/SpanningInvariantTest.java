package com.squirrelparser;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.FollowedBy;
import com.squirrelparser.Combinators.NotFollowedBy;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Optional;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Combinators.ZeroOrMore;
import com.squirrelparser.Terminals.Str;

/**
 * Parse Tree Spanning Invariant Tests
 *
 * These tests verify that Parser.parse() always returns a MatchResult
 * that completely spans the input (from position 0 to input.length).
 * - Total failures: SyntaxError spanning entire input
 * - Partial matches: wrapped with trailing SyntaxError
 * - Complete matches: result spans full input with no wrapper needed
 */
public class SpanningInvariantTest {

    @Test
    void testSpan01EmptyInput() {
        var parser = new Parser(Map.of("S", new Str("a")), "");
        var result = parser.parse("S");

        assertTrue(result instanceof SyntaxError, "Empty input with no match should be SyntaxError");
        assertEquals(0, result.len(), "SyntaxError should span full empty input");
        assertEquals(0, result.pos());
    }

    @Test
    void testSpan02CompleteMatchNoWrapper() {
        var parser = new Parser(Map.of("S", new Seq(new Str("a"), new Str("b"), new Str("c"))), "abc");
        var result = parser.parse("S");

        assertFalse(result instanceof SyntaxError, "Complete match should not be SyntaxError");
        assertEquals(3, result.len(), "Should span entire input");
        assertFalse(result.isMismatch());
    }

    @Test
    void testSpan03TotalFailureReturnsSyntaxError() {
        var parser = new Parser(Map.of("S", new Str("a")), "xyz");
        var result = parser.parse("S");

        assertTrue(result instanceof SyntaxError, "Total failure should be SyntaxError");
        assertEquals(3, result.len(), "SyntaxError should span entire input");
        assertEquals("xyz", ((SyntaxError) result).skipped());
    }

    @Test
    void testSpan04TrailingGarbageWrapped() {
        var parser = new Parser(Map.of("S", new Seq(new Str("a"), new Str("b"))), "abXYZ");
        var result = parser.parse("S");

        assertEquals(5, result.len(), "Result should span entire input");
        // Result spans entire input - either wrapped or has trailing errors captured
    }

    @Test
    void testSpan05SingleCharTrailing() {
        var parser = new Parser(Map.of("S", new Str("a")), "aX");
        var result = parser.parse("S");

        assertEquals(2, result.len(), "Should span full input");
        // Trailing character is captured in parse tree
    }

    @Test
    void testSpan06MultipleErrorsThroughout() {
        var parser = new Parser(Map.of("S", new Seq(new Str("a"), new Str("b"), new Str("c"))), "aXbYc");
        var result = parser.parse("S");

        assertEquals(5, result.len(), "Should span entire input");

        List<SyntaxError> errors = collectErrors(result);
        assertEquals(2, errors.size(), "Should have 2 syntax errors");
    }

    @Test
    void testSpan07RecoveryWithDeletion() {
        var parser = new Parser(Map.of("S", new Seq(new Str("a"), new Str("b"), new Str("c"))), "ab");
        var result = parser.parse("S");

        assertEquals(2, result.len(), "Should span full input (no trailing capture here)");
        assertFalse(result instanceof SyntaxError);
    }

    @Test
    void testSpan08FirstAlternativeWithTrailing() {
        var parser = new Parser(
                Map.of("S", new First(new Seq(new Str("a"), new Str("b"), new Str("c")), new Str("a"))),
                "abcX");
        var result = parser.parse("S");

        assertEquals(4, result.len(), "Should span entire input");

        boolean foundX = checkForTrailingX(result);
        assertTrue(foundX, "Should capture X as error");
    }

    @Test
    void testSpan09LeftRecursionWithTrailing() {
        var rules = new HashMap<String, Clause>();
        rules.put("E", new First(new Seq(new Ref("E"), new Str("+"), new Str("n")), new Str("n")));

        var parser = new Parser(rules, "n+nX");
        var result = parser.parse("E");

        assertEquals(4, result.len(), "Should span entire input");
        // LR expansion with trailing errors captured
    }

    @Test
    void testSpan10RepetitionWithTrailing() {
        var parser = new Parser(Map.of("S", new OneOrMore(new Str("a"))), "aaaX");
        var result = parser.parse("S");

        assertEquals(4, result.len(), "Should span entire input");

        boolean foundX = checkForTrailingX(result);
        assertTrue(foundX);
    }

    @Test
    void testSpan11NestedRulesWithTrailing() {
        var rules = new HashMap<String, Clause>();
        rules.put("S", new Seq(new Ref("A"), new Str(";")));
        rules.put("A", new Seq(new Str("a"), new Str("b")));

        var parser = new Parser(rules, "ab;X");
        var result = parser.parse("S");

        assertEquals(4, result.len(), "Should span entire input");
    }

    @Test
    void testSpan12ZeroOrMoreWithTrailing() {
        var parser = new Parser(Map.of("S", new ZeroOrMore(new Str("a"))), "XYZ");
        var result = parser.parse("S");

        assertEquals(3, result.len(), "Should span entire input");
        // Trailing errors captured in parse tree
    }

    @Test
    void testSpan13OptionalWithTrailing() {
        var parser = new Parser(Map.of("S", new Optional(new Str("a"))), "XYZ");
        var result = parser.parse("S");

        assertEquals(3, result.len(), "Should span entire input");

        boolean hasTrailingError = checkForAnyTrailingError(result);
        assertTrue(hasTrailingError);
    }

    @Test
    void testSpan14FollowedBySuccessWithTrailing() {
        var parser = new Parser(
                Map.of("S", new Seq(new FollowedBy(new Str("a")), new Str("a"), new Str("b"))),
                "abX");
        var result = parser.parse("S");

        assertEquals(3, result.len(), "Should span entire input");

        boolean foundX = checkForTrailingX(result);
        assertTrue(foundX);
    }

    @Test
    void testSpan15NotFollowedByFailureTotal() {
        var parser = new Parser(Map.of("S", new Seq(new NotFollowedBy(new Str("x")), new Str("y"))), "xz");
        var result = parser.parse("S");

        assertTrue(result instanceof SyntaxError, "Should be total failure");
        assertEquals(2, result.len(), "Should span entire input");
    }

    @Test
    void testSpan16OptionalWithTrailingSimple() {
        var parser = new Parser(Map.of("S", new Seq(new Str("b"), new Optional(new Str("c")))), "bX");
        var result = parser.parse("S");

        assertEquals(2, result.len(), "Should span entire input");

        boolean foundX = checkForTrailingX(result);
        assertTrue(foundX);
    }

    @Test
    void testSpan17InvariantNeverNull() {
        var testCases = Arrays.asList(
                new Object[]{Map.of("S", new Str("a")), "a"},
                new Object[]{Map.of("S", new Str("a")), "b"},
                new Object[]{Map.of("S", new Str("a")), ""},
                new Object[]{Map.of("S", new Seq(new Str("a"), new Str("b"))), "ab"},
                new Object[]{Map.of("S", new Seq(new Str("a"), new Str("b"))), "aXb"},
                new Object[]{Map.of("S", new First(new Str("a"), new Str("b"))), "c"});

        for (var testCase : testCases) {
            @SuppressWarnings("unchecked")
            var rules = (Map<String, Clause>) testCase[0];
            var input = (String) testCase[1];

            var parser = new Parser(rules, input);
            var result = parser.parse("S");

            assertNotNull(result, "parse() should never return null for input: " + input);
            assertEquals(input.length(), result.len(), "Result should span entire input for: " + input);
        }
    }

    @Test
    void testSpan18LongInputWithSingleTrailingError() {
        var chars = "abcdefghijklmnopqrstuvwxyz".split("");
        var input = "abcdefghijklmnopqrstuvwxyzX";

        List<Clause> clauseList = new ArrayList<>();
        for (String c : chars) {
            if (!c.isEmpty()) {
                clauseList.add(new Str(c));
            }
        }

        var parser = new Parser(Map.of("S", new Seq(clauseList.toArray(new Clause[0]))), input);
        var result = parser.parse("S");

        assertEquals(27, result.len(), "Should span entire input");
        // Trailing error captured in parse tree
    }

    @Test
    void testSpan19ComplexGrammarWithErrors() {
        var rules = new HashMap<String, Clause>();
        rules.put("S", new Seq(new Ref("E"), new Str(";")));
        rules.put("E", new First(new Seq(new Ref("E"), new Str("+"), new Ref("T")), new Ref("T")));
        rules.put("T", new Str("n"));

        var parser = new Parser(rules, "n+Xn;Y");
        var result = parser.parse("S");

        assertEquals(6, result.len(), "Should span entire input");
        // Multiple errors captured in parse tree
    }

    @Test
    void testSpan20RecoveryPreservesMatchedContent() {
        var parser = new Parser(
                Map.of("S", new Seq(new Str("hello"), new Str(" "), new Str("world"))),
                "hello X world");
        var result = parser.parse("S");

        assertEquals(13, result.len(), "Should span entire input");
        assertFalse(result instanceof SyntaxError);

        // Verify there's an error for skipped X
        List<SyntaxError> errors = collectErrors(result);
        assertTrue(errors.size() > 0, "Should have error for skipped X");
    }

    // Helper methods

    private boolean checkForAnyTrailingError(MatchResult r) {
        if (r instanceof SyntaxError) {
            return true;
        }
        for (var child : r.subClauseMatches()) {
            if (checkForAnyTrailingError(child)) {
                return true;
            }
        }
        return false;
    }

    private boolean checkForTrailingX(MatchResult r) {
        if (r instanceof SyntaxError err && err.skipped().contains("X")) {
            return true;
        }
        for (var child : r.subClauseMatches()) {
            if (checkForTrailingX(child)) {
                return true;
            }
        }
        return false;
    }

    private List<SyntaxError> collectErrors(MatchResult r) {
        var errors = new ArrayList<SyntaxError>();
        collectErrorsHelper(r, errors);
        return errors;
    }

    private void collectErrorsHelper(MatchResult r, List<SyntaxError> errors) {
        if (r instanceof SyntaxError err) {
            errors.add(err);
        }
        for (var child : r.subClauseMatches()) {
            collectErrorsHelper(child, errors);
        }
    }
}
