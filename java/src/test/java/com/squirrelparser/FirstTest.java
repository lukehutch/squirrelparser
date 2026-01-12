// ===========================================================================
// SECTION 8: FIRST (ORDERED CHOICE) (8 tests)
// ===========================================================================

package com.squirrelparser;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;
import static com.squirrelparser.TestUtils.*;

class FirstTest {
    @Test
    void fr01_match1st() {
        var result = testParse(
            "S <- \"abc\" / \"ab\" / \"a\" ;",
            "abc"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void fr02_match2nd() {
        var result = testParse(
            "S <- \"xyz\" / \"abc\" ;",
            "abc"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void fr03_match3rd() {
        var result = testParse(
            "S <- \"x\" / \"y\" / \"z\" ;",
            "z"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void fr04_withRecovery() {
        var result = testParse(
            "S <- \"x\"+ \"!\" / \"fallback\" ;",
            "xZx!"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("Z"), "should skip Z");
    }

    @Test
    void fr05_fallback() {
        var result = testParse(
            "S <- \"a\" \"b\" / \"x\" ;",
            "x"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void fr06_noneMatch() {
        var result = testParse(
            "S <- \"a\" / \"b\" / \"c\" ;",
            "x"
        );
        assertFalse(result.ok(), "should fail");
    }

    @Test
    void fr07_nested() {
        var result = testParse(
            "S <- (\"a\" / \"b\") / \"c\" ;",
            "b"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void fr08_deepNested() {
        var result = testParse(
            "S <- ((\"a\")) ;",
            "a"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }
}
