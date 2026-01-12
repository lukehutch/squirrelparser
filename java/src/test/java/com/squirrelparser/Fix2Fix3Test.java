// ===========================================================================
// SECTION 3: FIX #2/#3 - CACHE INTEGRITY (20 tests)
// ===========================================================================

package com.squirrelparser;

import static com.squirrelparser.TestUtils.testParse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class Fix2Fix3Test {

    @Test
    void F2_01_Basic_probe() {
        var result = testParse("S <- \"(\" \"x\"+ \")\" ;", "(xZZx)");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("ZZ")), "should skip ZZ");
    }

    @Test
    void F2_02_Double_probe() {
        var result = testParse("S <- \"a\" \"x\"+ \"b\" \"y\"+ \"c\" ;", "axXxbyYyc");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
    }

    @Test
    void F2_03_Probe_same_clause() {
        var result = testParse("S <- (\"(\" \"x\"+ \")\")+ ;", "(xZx)(xYx)");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z"))
                && result.skippedStrings().stream().anyMatch(s -> s.contains("Y")),
                "should skip Z and Y");
    }

    @Test
    void F2_04_Triple_group() {
        var result = testParse("S <- (\"[\" \"x\"+ \"]\")+ ;", "[xAx][xBx][xCx]");
        assertTrue(result.ok(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
    }

    @Test
    void F2_05_Five_groups() {
        var result = testParse("S <- (\"(\" \"x\"+ \")\")+ ;", "(xAx)(xBx)(xCx)(xDx)(xEx)");
        assertTrue(result.ok(), "should succeed");
        assertEquals(5, result.errorCount(), "should have 5 errors");
    }

    @Test
    void F2_06_Alternating_clean_err() {
        var result = testParse("S <- (\"(\" \"x\"+ \")\")+ ;", "(xx)(xZx)(xx)(xYx)(xx)");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
    }

    @Test
    void F2_07_Long_inner_error() {
        var result = testParse("S <- \"(\" \"x\"+ \")\" ;", "(x" + "Z".repeat(20) + "x)");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
    }

    @Test
    void F2_08_Nested_probe() {
        var result = testParse("S <- \"{\" \"(\" \"x\"+ \")\" \"}\" ;", "{(xZx)}");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F2_09_Triple_nested() {
        var result = testParse("S <- \"<\" \"{\" \"[\" \"x\"+ \"]\" \"}\" \">\" ;", "<{[xZx]}>");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F2_10_Ref_probe() {
        var result = testParse("""
            S <- "(" R ")" ;
            R <- "x"+ ;
            """, "(xZx)");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }
}
