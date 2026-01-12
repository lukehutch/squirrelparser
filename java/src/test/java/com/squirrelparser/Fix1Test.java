// ===========================================================================
// SECTION 2: FIX #1 - isComplete PROPAGATION (25 tests)
// ===========================================================================

package com.squirrelparser;

import org.junit.jupiter.api.Test;

import static com.squirrelparser.TestUtils.testParse;
import static org.junit.jupiter.api.Assertions.*;

class Fix1Test {

    @Test
    void F1_01_RepPlusSeq_basic() {
        var result = testParse("S <- \"ab\"+ \"!\" ;", "abXXab!");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error, got " + result.errorCount());
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("XX")), "should skip XX");
    }

    @Test
    void F1_02_RepPlusOptional() {
        var result = testParse("S <- \"ab\"+ \"!\"? ;", "abXXab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("XX")), "should skip XX");
    }

    @Test
    void F1_03_RepPlusOptional_match() {
        var result = testParse("S <- \"ab\"+ \"!\"? ;", "abXXab!");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("XX")), "should skip XX");
    }

    @Test
    void F1_04_First_wrapping() {
        var result = testParse("S <- (\"ab\"+ \"!\") ;", "abXXab!");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
    }

    @Test
    void F1_05_Nested_Seq_L1() {
        var result = testParse("S <- ((\"x\"+)) ;", "xZx");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F1_06_Nested_Seq_L2() {
        var result = testParse("S <- (((\"x\"+))) ;", "xZx");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F1_07_Nested_Seq_L3() {
        var result = testParse("S <- ((((\"x\"+)))) ;", "xZx");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F1_08_Optional_wrapping() {
        var result = testParse("S <- ((\"x\"+))? ;", "xZx");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F1_09_ZeroOrMore_in_Seq() {
        var result = testParse("S <- \"ab\"* \"!\" ;", "abXXab!");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("XX")), "should skip XX");
    }

    @Test
    void F1_10_Multiple_Reps() {
        var result = testParse("S <- \"a\"+ \"b\"+ ;", "aXabYb");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
    }

    @Test
    void F1_11_RepPlusRepPlusTerm() {
        var result = testParse("S <- \"a\"+ \"b\"+ \"!\" ;", "aXabYb!");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
    }

    @Test
    void F1_12_Long_error_span() {
        var result = testParse("S <- \"x\"+ \"!\" ;", "x" + "Z".repeat(20) + "x!");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
    }

    @Test
    void F1_13_Multiple_long_errors() {
        var result = testParse("S <- \"ab\"+ ;", "ab" + "X".repeat(10) + "ab" + "Y".repeat(10) + "ab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
    }

    @Test
    void F1_14_Interspersed_errors() {
        var result = testParse("S <- \"ab\"+ ;", "abXabYabZab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
    }

    @Test
    void F1_15_Five_errors() {
        var result = testParse("S <- \"ab\"+ ;", "abAabBabCabDabEab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(5, result.errorCount(), "should have 5 errors");
    }
}
