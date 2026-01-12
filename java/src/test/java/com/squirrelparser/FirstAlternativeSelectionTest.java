// ===========================================================================
// FIRST ALTERNATIVE SELECTION TESTS (FIX #2 Verification)
// ===========================================================================
// These tests verify that First correctly selects alternatives based on
// length priority (longer matches preferred) with error count as tiebreaker.

package com.squirrelparser;

import org.junit.jupiter.api.Test;

import static com.squirrelparser.TestUtils.*;
import static org.junit.jupiter.api.Assertions.*;

class FirstAlternativeSelectionTest {

    @Test
    void first01_allAlternativesFailCleanly() {
        // All alternatives mismatch, no recovery possible
        var result = testParse("S <- \"a\" / \"b\" / \"c\" ;", "x");
        assertFalse(result.ok(), "should fail (no alternative matches)");
    }

    @Test
    void first02_firstNeedsRecoverySecondClean() {
        // FIX #2: Prefer longer matches, so first alternative wins despite error
        var result = testParse("S <- \"a\" \"b\" / \"c\" ;", "aXb");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "first alternative chosen (longer despite error)");
    }

    @Test
    void first03_allAlternativesNeedRecovery() {
        // Multiple alternatives with recovery, choose best
        var result = testParse("S <- \"a\" \"b\" \"c\" / \"a\" \"y\" \"z\" ;", "aXbc");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should choose first alternative (matches with recovery)");
    }

    @Test
    void first04_longerWithErrorVsShorterClean() {
        // FIX #2: Length priority - longer wins even with error
        var result = testParse("S <- \"a\" \"b\" \"c\" / \"a\" ;", "aXbc");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should choose first (longer despite error)");
    }

    @Test
    void first05_sameLengthFewerErrorsWins() {
        // Same length, fewer errors wins
        var result = testParse("S <- \"a\" \"b\" \"c\" \"d\" / \"a\" \"b\" \"c\" ;", "aXbc");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should choose second (fewer errors)");
    }

    @Test
    void first06_multipleCleanAlternatives() {
        // Multiple alternatives match cleanly, first wins
        var result = testParse("S <- \"abc\" / \"abc\" / \"ab\" ;", "abc");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors (clean match)");
        // First alternative wins
    }

    @Test
    void first07_preferLongerCleanOverShorterClean() {
        // Two clean alternatives, different lengths
        var result = testParse("S <- \"abc\" / \"ab\" ;", "abc");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // First matches full input (len=3), second would match len=2
        // But First tries in order, so first wins anyway
    }

    @Test
    void first08_fallbackAfterAllLongerFail() {
        // Longer alternatives fail, shorter succeeds
        var result = testParse("S <- \"x\" \"y\" \"z\" / \"a\" ;", "a");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors (clean second alternative)");
    }

    @Test
    void first09_leftRecursiveAlternative() {
        // First contains left-recursive alternative
        var result = testParse("E <- E \"+\" \"n\" / \"n\" ;", "n+Xn", "E");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        // LR expansion with recovery
    }

    @Test
    void first10_nestedFirst() {
        // First containing another First
        var result = testParse("S <- (\"a\" / \"b\") / \"c\" ;", "b");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // Outer First tries first alternative (inner First), which matches 'b'
    }

    @Test
    void first11_allAlternativesIncomplete() {
        // All alternatives incomplete (don't consume full input)
        // With new invariant, best match selected, trailing captured
        var result = testParse("S <- \"a\" / \"b\" ;", "aXXX");
        assertTrue(result.ok(), "should succeed with trailing captured");
        assertEquals(1, result.errorCount(), "should have 1 error (trailing XXX)");
        assertTrue(result.skippedStrings().contains("XXX"), "should capture XXX");
    }

    @Test
    void first12_recoveryWithComplexAlternatives() {
        // Complex alternatives with nested structures
        var result = testParse("S <- \"x\"+ \"y\" / \"a\"+ \"b\" ;", "xxxXy");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should choose first alternative");
    }
}
