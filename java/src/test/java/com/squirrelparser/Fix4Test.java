// ===========================================================================
// SECTION 4: FIX #4 - MULTI-LEVEL BOUNDED RECOVERY (35 tests)
// ===========================================================================

package com.squirrelparser;

import org.junit.jupiter.api.Test;

import java.util.stream.Collectors;
import java.util.stream.IntStream;

import static com.squirrelparser.TestUtils.testParse;
import static org.junit.jupiter.api.Assertions.*;

class Fix4Test {

    @Test
    void F4_L1_01_clean_2() {
        var result = testParse("S <- (\"(\" \"x\"+ \")\")+ ;", "(xx)(xx)");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void F4_L1_02_clean_5() {
        var result = testParse("S <- (\"(\" \"x\"+ \")\")+ ;", "(xx)".repeat(5));
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void F4_L1_03_err_first() {
        var result = testParse("S <- (\"(\" \"x\"+ \")\")+ ;", "(xZx)(xx)");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F4_L1_04_err_mid() {
        var result = testParse("S <- (\"(\" \"x\"+ \")\")+ ;", "(xx)(xZx)(xx)");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F4_L1_05_err_last() {
        var result = testParse("S <- (\"(\" \"x\"+ \")\")+ ;", "(xx)(xZx)");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F4_L1_06_err_all_3() {
        var result = testParse("S <- (\"(\" \"x\"+ \")\")+ ;", "(xAx)(xBx)(xCx)");
        assertTrue(result.ok(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("A"))
                && result.skippedStrings().stream().anyMatch(s -> s.contains("B"))
                && result.skippedStrings().stream().anyMatch(s -> s.contains("C")),
                "should skip A, B, C");
    }

    @Test
    void F4_L1_07_boundary() {
        var result = testParse("S <- (\"(\" \"x\"+ \")\")+ ;", "(xx)Z(xx)");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F4_L1_08_long_boundary() {
        var result = testParse("S <- (\"(\" \"x\"+ \")\")+ ;", "(xx)ZZZ(xx)");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("ZZZ")), "should skip ZZZ");
    }

    @Test
    void F4_L2_01_clean() {
        var result = testParse("S <- \"{\" (\"(\" \"x\"+ \")\")+ \"}\" ;", "{(xx)(xx)}");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void F4_L2_02_err_inner() {
        var result = testParse("S <- \"{\" (\"(\" \"x\"+ \")\")+ \"}\" ;", "{(xx)(xZx)}");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F4_L2_03_err_outer() {
        var result = testParse("S <- \"{\" (\"(\" \"x\"+ \")\")+ \"}\" ;", "{(xx)Z(xx)}");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F4_L2_04_both_levels() {
        var result = testParse("S <- \"{\" (\"(\" \"x\"+ \")\")+ \"}\" ;", "{(xAx)B(xCx)}");
        assertTrue(result.ok(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
    }

    @Test
    void F4_L3_01_clean() {
        var result = testParse("S <- \"[\" \"{\" (\"(\" \"x\"+ \")\")+ \"}\" \"]\" ;", "[{(xx)(xx)}]");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void F4_L3_02_err_deepest() {
        var result = testParse("S <- \"[\" \"{\" (\"(\" \"x\"+ \")\")+ \"}\" \"]\" ;", "[{(xx)(xZx)}]");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F4_N1_10_groups() {
        var result = testParse("S <- (\"(\" \"x\"+ \")\")+ ;", "(xx)".repeat(10));
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void F4_N2_10_groups_5_err() {
        String input = IntStream.range(0, 10)
                .mapToObj(i -> i % 2 == 0 ? "(xZx)" : "(xx)")
                .collect(Collectors.joining());
        var result = testParse("S <- (\"(\" \"x\"+ \")\")+ ;", input);
        assertTrue(result.ok(), "should succeed");
        assertEquals(5, result.errorCount(), "should have 5 errors");
    }

    @Test
    void F4_N3_20_groups() {
        var result = testParse("S <- (\"(\" \"x\"+ \")\")+ ;", "(xx)".repeat(20));
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }
}
