// ===========================================================================
// VISIBILITY CONSTRAINT TESTS (FIX #8 Verification)
// ===========================================================================
// These tests verify that parse trees match visible input structure and that
// grammar deletion (inserting missing elements) only occurs at EOF.

package com.squirrelparser;

import static com.squirrelparser.TestUtils.countDeletions;
import static com.squirrelparser.TestUtils.testParse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;

import org.junit.jupiter.api.Test;

class VisibilityConstraintTest {

    @Test
    void vis01_terminalAtomicity() {
        // Multi-char terminals are atomic - can't skip through them
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"abc\" \"def\" ;", "S", "abXdef");
        MatchResult result = parseResult.root();
        // Should fail - can't match 'abc' with 'abX', and can't skip 'X' mid-terminal
        // Total failure: result is a SyntaxError spanning entire input
        assertTrue(result instanceof SyntaxError, "should fail (cannot skip within multi-char terminal)");
    }

    @Test
    void vis02_grammarDeletionAtEof() {
        // Grammar deletion (completion) allowed at EOF
        var result = testParse("S <- \"a\" \"b\" \"c\" ;", "ab");
        assertTrue(result.ok(), "should succeed (delete c at EOF)");

        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"a\" \"b\" \"c\" ;", "S", "ab");
        assertEquals(1, countDeletions(List.of(parseResult.root())), "should have 1 deletion");
    }

    @Test
    void vis03_grammarDeletionMidParseForbidden() {
        // Grammar deletion NOT allowed mid-parse (FIX #8)
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"a\" \"b\" \"c\" ;", "S", "ac");
        MatchResult result = parseResult.root();
        // Should fail - cannot delete 'b' at position 1 (not EOF)
        // Total failure: result is a SyntaxError spanning entire input
        assertTrue(result instanceof SyntaxError, "should fail (mid-parse grammar deletion violates Visibility Constraint)");
    }

    @Test
    void vis04_treeStructureMatchesVisibleInput() {
        // Parse tree structure should match visible input structure
        var result = testParse("S <- \"a\" \"b\" \"c\" ;", "aXbc");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        // Visible input: a, X, b, c (4 elements)
        // Tree: a, SyntaxError(X), b, c (4 nodes)
    }

    @Test
    void vis05_hiddenDeletionCreatesMismatch() {
        // First tries alternatives; Seq needs 'b' but input is just 'a'
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"a\" \"b\" / \"c\" ;", "S", "a");
        MatchResult result = parseResult.root();
        // First alternative: Try Seq - 'a' matches, 'b' missing at EOF
        //   - Could delete 'b' at EOF, but that gives len=1
        // Second alternative: Try 'c' - fails (input is 'a')
        // Should pick first alternative with completion
        // Result always spans input, so check it's not a total failure
        assertFalse(result instanceof SyntaxError, "should succeed (first alternative with EOF deletion)");
        // With new invariant, result.len == input.length always
        assertEquals(1, result.len(), "should consume 1 char (a)");
    }

    @Test
    void vis06_multipleConsecutiveSkips() {
        // Multiple consecutive errors should be merged into one region
        var result = testParse("S <- \"a\" \"b\" \"c\" ;", "aXXXXbc");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (entire XXXX region)");
        assertTrue(result.skippedStrings().contains("XXXX"), "should skip XXXX as one region");
    }

    @Test
    void vis07_alternatingContentAndErrors() {
        // Pattern: valid, error, valid, error, valid, error, valid
        var result = testParse("S <- \"a\" \"b\" \"c\" \"d\" ;", "aXbYcZd");
        assertTrue(result.ok(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        assertTrue(result.skippedStrings().contains("Y"), "should skip Y");
        assertTrue(result.skippedStrings().contains("Z"), "should skip Z");
        // Tree: [a, SyntaxError(X), b, SyntaxError(Y), c, SyntaxError(Z), d]
    }

    @Test
    void vis08_completionVsCorrection() {
        // Completion (EOF): "user hasn't finished typing" - allowed
        var comp = testParse("S <- \"if\" \"(\" \"x\" \")\" ;", "if(x");
        assertTrue(comp.ok(), "completion should succeed");

        // Correction (mid-parse): "user typed wrong thing" - NOT allowed via grammar deletion
        ParseResult corrResult = SquirrelParser.squirrelParsePT("S <- \"if\" \"(\" \"x\" \")\" ;", "S", "if()");
        // Would need to delete 'x' at position 3, but ')' remains - not EOF
        MatchResult result = corrResult.root();
        // Total failure: result is a SyntaxError spanning entire input
        assertTrue(result instanceof SyntaxError, "mid-parse correction should fail");
    }

    @Test
    void vis09_structuralIntegrity() {
        // Tree must reflect what user sees, not what we wish they typed
        var result = testParse("S <- \"(\" \"E\" \")\" ;", "E)");
        // User sees: E, )
        // Should NOT reinterpret as: (, E, ) by "inserting" ( at start
        // Should fail - cannot delete '(' mid-parse
        assertFalse(result.ok(), "should fail (cannot reorganize visible structure)");
    }

    @Test
    void vis10_visibilityWithNestedStructures() {
        // Nested Seq - errors at each level should preserve visibility
        var result = testParse("S <- (\"a\" \"b\") \"c\" ;", "aXbc");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("X"), "should skip X in inner Seq");
    }
}
