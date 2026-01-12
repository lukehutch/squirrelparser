// ===========================================================================
// BOUNDARY PRESERVATION TESTS
// ===========================================================================
// These tests verify that recovery doesn't consume content meant for
// subsequent grammar elements (preserve structural boundaries).

package com.squirrelparser;

import static com.squirrelparser.TestUtils.testParse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class BoundaryPreservationTest {

    @Test
    void bnd01_dontConsumeNextTerminal() {
        // Recovery should skip 'X' but not consume 'b' (needed by next element)
        var result = testParse("S <- \"a\" \"b\" ;", "aXb");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        // Verify 'b' was matched by second element, not consumed during recovery
    }

    @Test
    void bnd02_dontPartiallyConsumeNextTerminal() {
        // Multi-char terminals are atomic - recovery can't consume part of 'cd'
        var result = testParse("S <- \"ab\" \"cd\" ;", "abXcd");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        // 'cd' should be matched atomically by second element
    }

    @Test
    void bnd03_recoveryInFirstDoesntPoisonAlternatives() {
        // First alternative fails cleanly, second succeeds
        var result = testParse("S <- \"a\" \"b\" / \"c\" \"d\" ;", "cd");
        assertTrue(result.ok(), "should succeed (second alternative)");
        assertEquals(0, result.errorCount(), "should have 0 errors (clean match)");
    }

    @Test
    void bnd04_firstAlternativeWithRecoveryVsSecondClean() {
        // First alternative needs recovery, second is clean
        // Should prefer first (longer match, see FIX #2)
        var result = testParse("S <- \"a\" \"b\" \"c\" / \"a\" ;", "aXbc");
        assertTrue(result.ok(), "should succeed");
        // FIX #2: Prefer longer matches over fewer errors
        assertEquals(1, result.errorCount(), "should choose first alternative (longer despite error)");
    }

    @Test
    void bnd05_boundaryWithNestedRepetition() {
        // Repetition with bound should stop at delimiter
        var result = testParse("S <- \"x\"+ \";\" \"y\"+ ;", "xxx;yyy");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // x+ stops at ';', y+ stops at EOF
    }

    @Test
    void bnd06_boundaryWithRecoveryBeforeDelimiter() {
        // Recovery happens, but delimiter is preserved
        var result = testParse("S <- \"x\"+ \";\" \"y\"+ ;", "xxXx;yyy");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        // ';' should not be consumed during recovery of x+
    }

    @Test
    void bnd07_probeRespectsBoundaries() {
        // ZeroOrMore probes ahead to find boundary
        var result = testParse("S <- \"x\"* (\"y\" / \"z\") ;", "xxxz");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // ZeroOrMore should probe, find 'z' matches First, stop before it
    }

    @Test
    void bnd08_complexBoundaryNesting() {
        // Nested sequences with multiple boundaries
        var result = testParse("S <- (\"a\"+ \"+\") (\"b\"+ \"=\") ;", "aaa+bbb=");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // Each repetition stops at its delimiter
    }

    @Test
    void bnd09_boundaryWithEof() {
        // No explicit boundary - should consume until EOF
        var result = testParse("S <- \"x\"+ ;", "xxxxx");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // Consumes all x's (no boundary to stop at)
    }

    @Test
    void bnd10_recoveryNearBoundary() {
        // Error just before boundary - should not cross boundary
        var result = testParse("S <- \"x\"+ \";\" ;", "xxX;");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        // ';' should remain for second element
    }
}
