// ===========================================================================
// SECTION 5: FIX #5/#6 - OPTIONAL AND EOF (25 tests)
// ===========================================================================

package com.squirrelparser;

import static com.squirrelparser.TestUtils.countDeletions;
import static com.squirrelparser.TestUtils.testParse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;

import org.junit.jupiter.api.Test;

class Fix5Fix6Test {

    // Mutual recursion grammar
    private static final String MR_GRAMMAR = """
        S <- A ;
        A <- "a" B / "y" ;
        B <- "b" A / "x" ;
        """;

    @Test
    void F5_01_aby() {
        var result = testParse(MR_GRAMMAR, "aby");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void F5_02_abZy() {
        var result = testParse(MR_GRAMMAR, "abZy");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F5_03_ababy() {
        var result = testParse(MR_GRAMMAR, "ababy");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void F5_04_ax() {
        var result = testParse(MR_GRAMMAR, "ax");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void F5_05_y() {
        var result = testParse(MR_GRAMMAR, "y");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void F5_06_abx() {
        // 'abx' is NOT in the language: after 'ab' we need A which requires 'a' or 'y', not 'x'
        // Grammar produces: y, ax, aby, abax, ababy, etc.
        // So this requires error recovery (skip 'b' and match 'ax', or skip 'bx' and fail)
        var result = testParse(MR_GRAMMAR, "abx");
        assertTrue(result.ok(), "should succeed with recovery");
        assertTrue(result.errorCount() >= 1, "should have at least 1 error");
    }

    @Test
    void F5_06b_abax() {
        // 'abax' IS in the language: A -> a B -> a b A -> a b a B -> a b a x
        var result = testParse(MR_GRAMMAR, "abax");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void F5_07_ababx() {
        // 'ababx' is NOT in the language: after 'abab' we need A which requires 'a' or 'y', not 'x'
        // Grammar produces: y, ax, aby, abax, ababy, ababax, abababy, etc.
        // So this requires error recovery
        var result = testParse(MR_GRAMMAR, "ababx");
        assertTrue(result.ok(), "should succeed with recovery");
        assertTrue(result.errorCount() >= 1, "should have at least 1 error");
    }

    @Test
    void F5_07b_ababax() {
        // 'ababax' IS in the language: A -> a B -> a b A -> a b a B -> a b a b A -> a b a b a B -> a b a b a x
        var result = testParse(MR_GRAMMAR, "ababax");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void F6_01_Optional_wrapper() {
        var result = testParse("S <- (\"x\"+ \"!\")? ;", "xZx!");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F6_02_Optional_at_EOF() {
        var result = testParse("S <- \"x\"? ;", "");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void F6_03_Nested_optional() {
        var result = testParse("S <- ((\"x\"+ \"!\")?)? ;", "xZx!");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F6_04_Optional_in_Seq() {
        var result = testParse("S <- (\"x\"+)? \"!\" ;", "xZx!");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void F6_05_EOF_del_ok() {
        var parseResult = SquirrelParser.squirrelParsePT("S <- \"a\" \"b\" \"c\" ;", "S", "ab");
        var root = parseResult.root();
        assertFalse(root.isMismatch(), "should succeed with recovery");
        assertEquals(1, countDeletions(List.of(root)), "should have 1 deletion");
    }
}
