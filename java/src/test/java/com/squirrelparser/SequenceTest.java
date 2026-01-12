// ===========================================================================
// SECTION 7: SEQUENCE COMPREHENSIVE (10 tests)
// ===========================================================================

package com.squirrelparser;

import static com.squirrelparser.TestUtils.countDeletions;
import static com.squirrelparser.TestUtils.testParse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;

import org.junit.jupiter.api.Test;

import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.ParseResult;
import com.squirrelparser.parser.SyntaxError;

class SequenceTest {
    @Test
    void s01_2elem() {
        var result = testParse(
            "S <- \"a\" \"b\" ;",
            "ab"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void s02_3elem() {
        var result = testParse(
            "S <- \"a\" \"b\" \"c\" ;",
            "abc"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void s03_5elem() {
        var result = testParse(
            "S <- \"a\" \"b\" \"c\" \"d\" \"e\" ;",
            "abcde"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void s04_insertMid() {
        var result = testParse(
            "S <- \"a\" \"b\" \"c\" ;",
            "aXXbc"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("XX"), "should skip XX");
    }

    @Test
    void s05_insertEnd() {
        var result = testParse(
            "S <- \"a\" \"b\" \"c\" ;",
            "abXXc"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("XX"), "should skip XX");
    }

    @Test
    void s06_delMid() {
        // Cannot delete grammar elements mid-parse (Fix #8 - Visibility Constraint)
        // Input "ac" with grammar "a" "b" "c" would require deleting "b" at position 1
        // Position 1 is not EOF (still have "c" to parse), so this violates constraints
        ParseResult parseResult = SquirrelParser.squirrelParsePT(
            "S <- \"a\" \"b\" \"c\" ;",
            "S",
            "ac"
        );
        MatchResult result = parseResult.root();
        // Should fail - cannot delete "b" mid-parse
        // Total failure: result is SyntaxError spanning entire input
        assertTrue(result instanceof SyntaxError,
            "should fail (mid-parse grammar deletion violates Visibility Constraint)");
    }

    @Test
    void s07_delEnd() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT(
            "S <- \"a\" \"b\" \"c\" ;",
            "S",
            "ab"
        );
        MatchResult result = parseResult.root();
        assertFalse(result.isMismatch(), "should succeed");
        assertEquals(1, countDeletions(List.of(result)), "should have 1 deletion");
    }

    @Test
    void s08_nestedClean() {
        var result = testParse(
            "S <- (\"a\" \"b\") \"c\" ;",
            "abc"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void s09_nestedInsert() {
        var result = testParse(
            "S <- (\"a\" \"b\") \"c\" ;",
            "aXbc"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
    }

    @Test
    void s10_longSeqClean() {
        var result = testParse(
            "S <- \"a\" \"b\" \"c\" \"d\" \"e\" \"f\" \"g\" \"h\" \"i\" \"j\" \"k\" \"l\" \"m\" \"n\" \"o\" \"p\" ;",
            "abcdefghijklmnop"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }
}
