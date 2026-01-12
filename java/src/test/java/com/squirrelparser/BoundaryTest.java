// ===========================================================================
// SECTION 1: EMPTY AND BOUNDARY CONDITIONS (27 tests)
// ===========================================================================

package com.squirrelparser;

import org.junit.jupiter.api.Test;

import java.util.List;

import static com.squirrelparser.TestUtils.*;
import static org.junit.jupiter.api.Assertions.*;

class BoundaryTest {

    @Test
    void e01_zeroOrMoreEmpty() {
        var result = testParse("S <- \"x\"* ;", "");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e02_oneOrMoreEmpty() {
        var result = testParse("S <- \"x\"+ ;", "");
        assertFalse(result.ok(), "should fail");
    }

    @Test
    void e03_optionalEmpty() {
        var result = testParse("S <- \"x\"? ;", "");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e04_seqEmptyRecovery() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT("S <- \"a\" \"b\" ;", "S", "");
        MatchResult result = parseResult.root();
        assertFalse(result.isMismatch(), "should succeed with recovery");
        assertEquals(2, countDeletions(List.of(result)), "should have 2 deletions");
    }

    @Test
    void e05_firstEmpty() {
        var result = testParse("S <- \"a\" / \"b\" ;", "");
        assertFalse(result.ok(), "should fail");
    }

    @Test
    void e06_refEmpty() {
        var result = testParse("S <- A ; A <- \"x\" ;", "");
        assertFalse(result.ok(), "should fail");
    }

    @Test
    void e07_singleCharMatch() {
        var result = testParse("S <- \"x\" ;", "x");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e08_singleCharMismatch() {
        var result = testParse("S <- \"x\" ;", "y");
        assertFalse(result.ok(), "should fail");
    }

    @Test
    void e09_zeroOrMoreSingle() {
        var result = testParse("S <- \"x\"* ;", "x");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e10_oneOrMoreSingle() {
        var result = testParse("S <- \"x\"+ ;", "x");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e11_optionalMatch() {
        var result = testParse("S <- \"x\"? ;", "x");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e12_twoCharsMatch() {
        var result = testParse("S <- \"xy\" ;", "xy");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e13_twoCharsPartial() {
        var result = testParse("S <- \"xy\" ;", "x");
        assertFalse(result.ok(), "should fail");
    }

    @Test
    void e14_charRangeMatch() {
        var result = testParse("S <- [a-z] ;", "m");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e15_charRangeBoundaryLow() {
        var result = testParse("S <- [a-z] ;", "a");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e16_charRangeBoundaryHigh() {
        var result = testParse("S <- [a-z] ;", "z");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e17_charRangeFailLow() {
        var result = testParse("S <- [b-y] ;", "a");
        assertFalse(result.ok(), "should fail");
    }

    @Test
    void e18_charRangeFailHigh() {
        var result = testParse("S <- [b-y] ;", "z");
        assertFalse(result.ok(), "should fail");
    }

    @Test
    void e19_anyCharMatch() {
        var result = testParse("S <- . ;", "x");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e20_anyCharEmpty() {
        var result = testParse("S <- . ;", "");
        assertFalse(result.ok(), "should fail");
    }

    @Test
    void e21_seqSingle() {
        var result = testParse("S <- (\"x\") ;", "x");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e22_firstSingle() {
        var result = testParse("S <- \"x\" ;", "x");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e23_nestedEmpty() {
        var result = testParse("S <- \"a\"? \"b\"? ;", "");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e24_zeroOrMoreMulti() {
        var result = testParse("S <- \"x\"* ;", "xxx");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e25_oneOrMoreMulti() {
        var result = testParse("S <- \"x\"+ ;", "xxx");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e26_longStringMatch() {
        var result = testParse("S <- \"abcdefghij\" ;", "abcdefghij");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void e27_longStringPartial() {
        var result = testParse("S <- \"abcdefghij\" ;", "abcdefghi");
        assertFalse(result.ok(), "should fail");
    }
}
