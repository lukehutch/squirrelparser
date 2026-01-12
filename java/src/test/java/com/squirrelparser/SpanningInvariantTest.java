// ===========================================================================
// PARSE TREE SPANNING INVARIANT TESTS
// ===========================================================================
// These tests verify that Parser.parse() always returns a MatchResult
// that completely spans the input (from position 0 to input.length).
// - Total failures: SyntaxError spanning entire input
// - Partial matches: wrapped with trailing SyntaxError
// - Complete matches: result spans full input with no wrapper needed

package com.squirrelparser;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;

import com.squirrelparser.parser.Match;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.ParseResult;
import com.squirrelparser.parser.SyntaxError;

class SpanningInvariantTest {

    /**
     * Helper to get a MatchResult that spans the entire input.
     * If there's an unmatchedInput, this wraps root and unmatchedInput together.
     */
    private MatchResult getSpanningResult(ParseResult parseResult) {
        if (parseResult.unmatchedInput() == null) {
            return parseResult.root();
        }

        MatchResult root = parseResult.root();

        // Total failure case: root is already SyntaxError spanning entire input
        if (root instanceof SyntaxError && root.len() == parseResult.input().length()) {
            return root;
        }

        // Create a synthetic Match that contains both root and unmatchedInput as children
        List<MatchResult> children = new ArrayList<>();
        if (root instanceof SyntaxError) {
            children.add(root);
            children.add(parseResult.unmatchedInput());
        } else {
            Match rootMatch = (Match) root;
            if (rootMatch.subClauseMatches().isEmpty()) {
                children.add(root);
                children.add(parseResult.unmatchedInput());
            } else {
                children.addAll(rootMatch.subClauseMatches());
                children.add(parseResult.unmatchedInput());
            }
        }

        return new Match(root.clause(), 0, parseResult.input().length(), children, true, false,
            root.totDescendantErrors() + 1);
    }

    private boolean hasTrailingError(MatchResult result, String input, int pos, int len) {
        if (result instanceof SyntaxError se) {
            return se.pos() == pos && se.len() == len;
        }
        for (MatchResult child : result.subClauseMatches()) {
            if (hasTrailingError(child, input, pos, len)) {
                return true;
            }
        }
        return false;
    }

    private boolean hasSyntaxError(MatchResult result) {
        if (result instanceof SyntaxError) {
            return true;
        }
        for (MatchResult child : result.subClauseMatches()) {
            if (hasSyntaxError(child)) {
                return true;
            }
        }
        return false;
    }

    private List<SyntaxError> collectErrors(MatchResult result) {
        List<SyntaxError> errors = new ArrayList<>();
        collectErrorsRecursive(result, errors);
        return errors;
    }

    private void collectErrorsRecursive(MatchResult result, List<SyntaxError> errors) {
        if (result instanceof SyntaxError se) {
            errors.add(se);
        }
        for (MatchResult child : result.subClauseMatches()) {
            collectErrorsRecursive(child, errors);
        }
    }

    @Test
    void span01_emptyInput() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"a\" ;", "S", "");
        MatchResult result = getSpanningResult(parseResult);

        assertTrue(result instanceof SyntaxError, "Empty input with no match should be SyntaxError");
        assertEquals(0, result.len(), "SyntaxError should span full empty input");
        assertEquals(0, result.pos());
    }

    @Test
    void span02_completeMatchNoWrapper() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"a\" \"b\" \"c\" ;", "S", "abc");
        MatchResult result = getSpanningResult(parseResult);

        assertFalse(result instanceof SyntaxError, "Complete match should not be SyntaxError");
        assertEquals(3, result.len(), "Should span entire input");
        assertFalse(result.isMismatch());
    }

    @Test
    void span03_totalFailureReturnsSyntaxError() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"a\" ;", "S", "xyz");
        MatchResult result = getSpanningResult(parseResult);

        assertTrue(result instanceof SyntaxError, "Total failure should be SyntaxError");
        assertEquals(3, result.len(), "SyntaxError should span entire input");
    }

    @Test
    void span04_trailingGarbageWrapped() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"a\" \"b\" ;", "S", "abXYZ");
        MatchResult result = getSpanningResult(parseResult);

        assertEquals(5, result.len(), "Result should span entire input");
        assertFalse(result instanceof SyntaxError, "Result is wrapper Match");
        assertTrue(hasTrailingError(result, parseResult.input(), 2, 3), "Should contain SyntaxError for trailing XYZ");
    }

    @Test
    void span05_singleCharTrailing() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"a\" ;", "S", "aX");
        MatchResult result = getSpanningResult(parseResult);

        assertNotNull(parseResult.unmatchedInput(), "Should have unmatchedInput for trailing X");
        assertEquals(2, result.len(), "Should span full input");
        assertFalse(result instanceof SyntaxError);
        assertTrue(hasTrailingError(result, parseResult.input(), 1, 1));
    }

    @Test
    void span06_multipleErrorsThroughout() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"a\" \"b\" \"c\" ;", "S", "aXbYc");
        MatchResult result = getSpanningResult(parseResult);

        assertEquals(5, result.len(), "Should span entire input");

        List<SyntaxError> errors = collectErrors(result);
        assertEquals(2, errors.size(), "Should have 2 syntax errors");
    }

    @Test
    void span07_recoveryWithDeletion() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"a\" \"b\" \"c\" ;", "S", "ab");
        MatchResult result = getSpanningResult(parseResult);

        assertEquals(2, result.len(), "Should span full input (no trailing capture here)");
        assertFalse(result instanceof SyntaxError);
    }

    @Test
    void span08_firstAlternativeWithTrailing() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"a\" \"b\" \"c\" / \"a\" ;", "S", "abcX");
        MatchResult result = getSpanningResult(parseResult);

        assertEquals(4, result.len(), "Should span entire input");
        assertTrue(hasSyntaxError(result), "Should capture X as error");
    }

    @Test
    void span09_leftRecursionWithTrailing() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("E <- E \"+\" \"n\" / \"n\" ;", "E", "n+nX");
        MatchResult result = getSpanningResult(parseResult);

        assertEquals(4, result.len(), "Should span entire input");
        assertTrue(hasSyntaxError(result));
    }

    @Test
    void span10_repetitionWithTrailing() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"a\"+ ;", "S", "aaaX");
        MatchResult result = getSpanningResult(parseResult);

        assertEquals(4, result.len(), "Should span entire input");
        assertTrue(hasSyntaxError(result));
    }

    @Test
    void span11_nestedRulesWithTrailing() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("""
            S <- A ";" ;
            A <- "a" "b" ;
        """, "S", "ab;X");
        MatchResult result = getSpanningResult(parseResult);

        assertEquals(4, result.len(), "Should span entire input");
    }

    @Test
    void span12_zeroOrMoreWithTrailing() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"a\"* ;", "S", "XYZ");
        MatchResult result = getSpanningResult(parseResult);

        assertEquals(3, result.len(), "Should span entire input");
        assertFalse(result instanceof SyntaxError);
        assertTrue(hasSyntaxError(result));
    }

    @Test
    void span13_optionalWithTrailing() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"a\"? ;", "S", "XYZ");
        MatchResult result = getSpanningResult(parseResult);

        assertEquals(3, result.len(), "Should span entire input");
        assertTrue(hasSyntaxError(result));
    }

    @Test
    void span14_followedBySuccessWithTrailing() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- &\"a\" \"a\" \"b\" ;", "S", "abX");
        MatchResult result = getSpanningResult(parseResult);

        assertEquals(3, result.len(), "Should span entire input");
        assertTrue(hasTrailingError(result, parseResult.input(), 2, 1));
    }

    @Test
    void span15_notFollowedByFailureTotal() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- !\"x\" \"y\" ;", "S", "xz");
        MatchResult result = getSpanningResult(parseResult);

        assertTrue(result instanceof SyntaxError, "Should be total failure");
        assertEquals(2, result.len(), "Should span entire input");
    }

    @Test
    void span16_notFollowedBySuccessWithTrailing() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"b\" \"c\"? ;", "S", "bX");
        MatchResult result = getSpanningResult(parseResult);

        assertEquals(2, result.len(), "Should span entire input");
        assertTrue(hasTrailingError(result, parseResult.input(), 1, 1));
    }

    @Test
    void span17_invariantNeverNull() {
        String[][] testCases = {
            {"S <- \"a\" ;", "a"},
            {"S <- \"a\" ;", "b"},
            {"S <- \"a\" ;", ""},
            {"S <- \"a\" \"b\" ;", "ab"},
            {"S <- \"a\" \"b\" ;", "aXb"},
            {"S <- \"a\" / \"b\" ;", "c"},
        };

        for (String[] testCase : testCases) {
            String grammarSpec = testCase[0];
            String input = testCase[1];

            ParseResult parseResult = SquirrelParser.squirrelParsePT(grammarSpec, "S", input);
            MatchResult result = getSpanningResult(parseResult);

            assertNotNull(result, "parse() should never return null for input: " + input);
            assertEquals(input.length(), result.len(), "Result should span entire input for: " + input);
        }
    }

    @Test
    void span18_longInputWithSingleTrailingError() {
        String input = "abcdefghijklmnopqrstuvwxyzX";
        ParseResult parseResult = SquirrelParser.squirrelParsePT(
            "S <- \"a\" \"b\" \"c\" \"d\" \"e\" \"f\" \"g\" \"h\" \"i\" \"j\" \"k\" \"l\" \"m\" \"n\" \"o\" \"p\" \"q\" \"r\" \"s\" \"t\" \"u\" \"v\" \"w\" \"x\" \"y\" \"z\" ;",
            "S", input);
        MatchResult result = getSpanningResult(parseResult);

        assertEquals(27, result.len(), "Should span entire input");
        assertTrue(hasTrailingError(result, input, 26, 1));
    }

    @Test
    void span19_complexGrammarWithErrors() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("""
            S <- E ";" ;
            E <- E "+" T / T ;
            T <- "n" ;
        """, "S", "n+Xn;Y");
        MatchResult result = getSpanningResult(parseResult);

        assertEquals(6, result.len(), "Should span entire input");

        List<SyntaxError> errors = collectErrors(result);
        assertTrue(errors.size() >= 2, "Should capture errors");
    }

    @Test
    void span20_recoveryPreservesMatchedContent() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT(
            "S <- \"hello\" \" \" \"world\" ;", "S", "hello X world");
        MatchResult result = getSpanningResult(parseResult);

        assertEquals(13, result.len(), "Should span entire input");
        assertFalse(result instanceof SyntaxError);
        assertTrue(hasSyntaxError(result), "Should have error for skipped X");
    }
}
