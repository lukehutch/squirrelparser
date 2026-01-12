// ===========================================================================
// ONEORMORE FIRST-ITERATION RECOVERY TESTS (FIX #10 Verification)
// ===========================================================================
// These tests verify that OneOrMore allows recovery on the first iteration
// while still maintaining "at least one match" semantics.

package com.squirrelparser;

import static com.squirrelparser.TestUtils.testParse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class OneormoreRecoveryTest {

    @Test
    void om01_firstClean() {
        // Baseline: First iteration succeeds cleanly
        var result = testParse("S <- \"ab\"+ ;", "ababab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void om02_noMatchAnywhere() {
        // OneOrMore still requires at least one match
        var result = testParse("S <- \"ab\"+ ;", "xyz");
        assertFalse(result.ok(), "should fail (no match found)");
    }

    @Test
    void om03_skipToFirstMatch() {
        // FIX #10: Skip garbage to find first match
        var result = testParse("S <- \"ab\"+ ;", "Xab");
        assertTrue(result.ok(), "should succeed (skip X on first iteration)");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
    }

    @Test
    void om04_skipMultipleToFirst() {
        // FIX #10: Skip multiple characters to find first match
        var result = testParse("S <- \"ab\"+ ;", "XXXXXab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (entire skip)");
        assertTrue(result.skippedStrings().contains("XXXXX"), "should skip XXXXX");
    }

    @Test
    void om05_multipleIterationsWithErrors() {
        // FIX #10: First iteration with error, then more iterations with errors
        var result = testParse("S <- \"ab\"+ ;", "XabYabZab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        assertTrue(result.skippedStrings().contains("Y"), "should skip Y");
        assertTrue(result.skippedStrings().contains("Z"), "should skip Z");
    }

    @Test
    void om06_firstWithErrorThenClean() {
        // First iteration skips error, subsequent iterations clean
        var result = testParse("S <- \"ab\"+ ;", "Xabababab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (only X)");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
    }

    @Test
    void om07_vsZeroormoreSemantics() {
        // BOTH ZeroOrMore and OneOrMore fail on input with no matches
        // because parseWithRecovery requires parsing the ENTIRE input.
        // ZeroOrMore matches 0 times (len=0), leaving "XYZ" unparsed.
        // OneOrMore matches 0 times (fails "at least one"), also leaving input unparsed.

        // Key difference: Empty input
        var zrEmpty = testParse("S <- \"ab\"* ;", "");
        assertTrue(zrEmpty.ok(), "ZeroOrMore should succeed on empty input");
        assertEquals(0, zrEmpty.errorCount(), "should have 0 errors");

        var orEmpty = testParse("S <- \"ab\"+ ;", "");
        assertFalse(orEmpty.ok(), "OneOrMore should fail on empty input");

        // Key difference: With valid matches
        var zrMatch = testParse("S <- \"ab\"* ;", "ababab");
        assertTrue(zrMatch.ok(), "ZeroOrMore succeeds with matches");

        var orMatch = testParse("S <- \"ab\"+ ;", "ababab");
        assertTrue(orMatch.ok(), "OneOrMore succeeds with matches");
    }

    @Test
    void om08_longSkipPerformance() {
        // Large skip distance should still complete quickly
        var input = "X".repeat(100) + "ab";
        var result = testParse("S <- \"ab\"+ ;", input);
        assertTrue(result.ok(), "should succeed (performance test)");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertEquals(100, result.skippedStrings().get(0).length(), "should skip 100 X's");
    }

    @Test
    void om09_exhaustiveSearchNoMatch() {
        // Try all positions, find nothing, fail cleanly
        var input = "X".repeat(50) + "Y".repeat(50); // No 'ab' anywhere
        var result = testParse("S <- \"ab\"+ ;", input);
        assertFalse(result.ok(), "should fail (exhaustive search finds nothing)");
    }

    @Test
    void om10_firstIterationWithBound() {
        // First iteration recovery + bound checking
        var result = testParse("S <- \"ab\"+ \"end\" ;", "XabYabend");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors (X and Y)");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        assertTrue(result.skippedStrings().contains("Y"), "should skip Y");
    }

    @Test
    void om11_alternatingPattern() {
        // Pattern: error, match, error, match, ...
        var result = testParse("S <- \"ab\"+ ;", "XabXabXabXab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(4, result.errorCount(), "should have 4 errors (4 X's)");
    }

    @Test
    void om12_multiCharTerminalFirst() {
        // Multi-character terminal with first-iteration recovery
        var result = testParse("S <- \"hello\"+ ;", "XXXhellohello");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("XXX"), "should skip XXX");
    }
}
