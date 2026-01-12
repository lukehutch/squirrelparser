// ===========================================================================
// SECTION 10: UNICODE AND SPECIAL (10 tests)
// ===========================================================================

package com.squirrelparser;

import static com.squirrelparser.TestUtils.testParse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class UnicodeTest {

    @Test
    void u01_greek() {
        var result = testParse("S <- \"\u03b1\"+ ;", "\u03b1\u03b2\u03b1");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("\u03b2"), "should skip \u03b2");
    }

    @Test
    void u02_chinese() {
        var result = testParse("S <- \"\u4e2d\"+ ;", "\u4e2d\u6587\u4e2d");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("\u6587"), "should skip \u6587");
    }

    @Test
    void u03_arabicClean() {
        var result = testParse("S <- \"\u0645\"+ ;", "\u0645\u0645\u0645");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void u04_newline() {
        var result = testParse("S <- \"x\"+ ;", "x\nx");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("\n"), "should skip newline");
    }

    @Test
    void u05_tab() {
        var result = testParse("S <- \"a\" \"\\t\" \"b\" ;", "a\tb");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void u06_space() {
        var result = testParse("S <- \"x\"+ ;", "x x");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains(" "), "should skip space");
    }

    @Test
    void u07_multiSpace() {
        var result = testParse("S <- \"x\"+ ;", "x   x");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("   "), "should skip spaces");
    }

    @Test
    void u08_japanese() {
        var result = testParse("S <- \"\u65e5\"+ ;", "\u65e5\u672c\u65e5");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("\u672c"), "should skip \u672c");
    }

    @Test
    void u09_korean() {
        var result = testParse("S <- \"\ud55c\"+ ;", "\ud55c\uae00\ud55c");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("\uae00"), "should skip \uae00");
    }

    @Test
    void u10_mixedScripts() {
        var result = testParse("S <- \"\u03b1\" \"\u4e2d\" \"!\" ;", "\u03b1\u4e2d!");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }
}
