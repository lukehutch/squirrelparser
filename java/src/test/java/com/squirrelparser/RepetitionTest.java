// ===========================================================================
// SECTION 6: REPETITION COMPREHENSIVE (20 tests)
// ===========================================================================

package com.squirrelparser;

import static com.squirrelparser.TestUtils.testParse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.stream.Collectors;
import java.util.stream.IntStream;

import org.junit.jupiter.api.Test;

class RepetitionTest {
    @Test
    void r01_between() {
        var result = testParse("S <- \"ab\"+ ;", "abXXab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("XX"), "should skip XX");
    }

    @Test
    void r02_multi() {
        var result = testParse("S <- \"ab\"+ ;", "abXabYab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
        assertTrue(result.skippedStrings().contains("X") && result.skippedStrings().contains("Y"),
            "should skip X and Y");
    }

    @Test
    void r03_longSkip() {
        var result = testParse("S <- \"ab\"+ ;", "ab" + "X".repeat(50) + "ab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
    }

    @Test
    void r04_zeroOrMoreStart() {
        var result = testParse("S <- \"ab\"* \"!\" ;", "XXab!");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("XX"), "should skip XX");
    }

    @Test
    void r05_beforeFirst() {
        // FIX #10: OneOrMore now allows first-iteration recovery
        var result = testParse("S <- \"ab\"+ ;", "XXab");
        assertTrue(result.ok(), "should succeed (skip XX on first iteration)");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("XX"), "should skip XX");
    }

    @Test
    void r06_trailingCaptured() {
        // With new invariant, trailing errors are captured in parse tree
        var result = testParse("S <- \"ab\"+ ;", "ababXX");
        assertTrue(result.ok(), "should succeed with trailing captured");
        assertEquals(1, result.errorCount(), "should have 1 error (trailing XX)");
        assertTrue(result.skippedStrings().contains("XX"), "should skip XX");
    }

    @Test
    void r07_single() {
        var result = testParse("S <- \"ab\"+ ;", "ab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void r08_zeroOrMoreEmpty() {
        var result = testParse("S <- \"ab\"* ;", "");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void r09_alternating() {
        var result = testParse("S <- \"ab\"+ ;", "abXabXabXab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
    }

    @Test
    void r10_longClean() {
        var result = testParse("S <- \"x\"+ ;", "x".repeat(100));
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void r11_longErr() {
        var result = testParse("S <- \"x\"+ ;", "x".repeat(50) + "Z" + "x".repeat(49));
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("Z"), "should skip Z");
    }

    @Test
    void r12_20errors() {
        @SuppressWarnings("unused")
        String input = IntStream.range(0, 20).mapToObj(i -> "abZ").collect(Collectors.joining()) + "ab";
        var result = testParse("S <- \"ab\"+ ;", input);
        assertTrue(result.ok(), "should succeed");
        assertEquals(20, result.errorCount(), "should have 20 errors");
    }

    @Test
    void r13_veryLong() {
        var result = testParse("S <- \"ab\"+ ;", "ab".repeat(500));
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void r14_veryLongErr() {
        var result = testParse("S <- \"ab\"+ ;", "ab".repeat(250) + "ZZ" + "ab".repeat(249));
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
    }

    // Tests for trailing error recovery (Issue: abxbxax failing completely)
    // These tests ensure that after recovering from errors in the middle,
    // the parser also captures trailing unmatched input as errors.

    @Test
    void r15_trailingSingleCharAfterRecovery() {
        // After recovering from middle errors, trailing 'x' should also be caught as error
        var result = testParse("""
            S <- A ;
            A <- ("a" / "b")+ ;
        """, "abxbxax");
        assertTrue(result.ok(), "should succeed with recovery");
        assertEquals(3, result.errorCount(), "should have 3 errors (x at positions 2, 4, 6)");
        assertEquals(3, result.skippedStrings().size(), "should skip 3 chars total");
    }

    @Test
    void r16_trailingMultipleCharsAfterRecovery() {
        // Multiple trailing errors after recovery
        var result = testParse("S <- \"ab\"+ ;", "abXabXabXX");
        assertTrue(result.ok(), "should succeed with recovery");
        assertEquals(3, result.errorCount(), "should have 3 errors");
        assertEquals(3, result.skippedStrings().size(), "should skip 3 occurrences");
    }

    @Test
    void r17_trailingLongErrorAfterRecovery() {
        // Long trailing error after recovery
        var result = testParse("S <- \"x\"+ ;", "x".repeat(50) + "Z" + "x".repeat(49) + "YYYY");
        assertTrue(result.ok(), "should succeed with recovery");
        assertEquals(2, result.errorCount(), "should have 2 errors (Z and YYYY)");
    }

    @Test
    void r18_trailingAfterMultipleAlternatingErrors() {
        // Multiple errors throughout, then trailing error
        var result = testParse("S <- \"ab\"+ ;", "abXabYabZabXX");
        assertTrue(result.ok(), "should succeed with recovery");
        assertEquals(4, result.errorCount(), "should have 4 errors (X, Y, Z, XX)");
    }

    @Test
    void r19_singleCharAfterFirstRecovery() {
        // Recovery on first iteration, then trailing error
        var result = testParse("S <- \"ab\"+ ;", "XXabX");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors (XX and X)");
        assertTrue(result.skippedStrings().contains("XX") && result.skippedStrings().contains("X"),
            "should skip both XX and X");
    }

    @Test
    void r20_trailingErrorWithSingleElement() {
        // Single valid element followed by recovery, then trailing
        var result = testParse("S <- \"a\"+ ;", "aXaY");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors (X and Y)");
    }
}
