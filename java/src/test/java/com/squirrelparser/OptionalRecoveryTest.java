// ===========================================================================
// OPTIONAL WITH RECOVERY TESTS
// ===========================================================================
// These tests verify Optional behavior with and without recovery.

package com.squirrelparser;

import static com.squirrelparser.TestUtils.testParse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class OptionalRecoveryTest {

    @Test
    void opt01_optionalMatchesCleanly() {
        // Optional matches its content cleanly
        var result = testParse("S <- \"a\"? \"b\" ;", "ab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // Optional matches 'a', then 'b'
    }

    @Test
    void opt02_optionalFallsThroughCleanly() {
        // Optional doesn't match, falls through
        var result = testParse("S <- \"a\"? \"b\" ;", "b");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // Optional returns empty match (len=0), then 'b' matches
    }

    @Test
    void opt03_optionalWithRecoveryAttempt() {
        // Optional content needs recovery - should Optional try recovery or fall through?
        // Current behavior: Optional tries recovery
        var result = testParse("S <- (\"a\" \"b\")? ;", "aXb");
        assertTrue(result.ok(), "should succeed");
        // If Optional attempts recovery: err=1, skip=['X']
        // If Optional falls through: err=0, but incomplete parse
        assertEquals(1, result.errorCount(), "Optional should attempt recovery");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
    }

    @Test
    void opt04_optionalInSequence() {
        // Optional in middle of sequence
        var result = testParse("S <- \"a\" \"b\"? \"c\" ;", "ac");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // 'a' matches, Optional falls through, 'c' matches
    }

    @Test
    void opt05_nestedOptional() {
        // Optional(Optional(...))
        var result = testParse("S <- \"a\"?? \"b\" ;", "b");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // Both optionals return empty
    }

    @Test
    void opt06_optionalWithFirst() {
        // Optional(First([...]))
        var result = testParse("S <- (\"a\" / \"b\")? \"c\" ;", "bc");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // Optional matches First's second alternative 'b'
    }

    @Test
    void opt07_optionalWithRepetition() {
        // Optional(OneOrMore(...))
        var result = testParse("S <- \"x\"+? \"y\" ;", "xxxy");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // Optional matches OneOrMore which matches 3 x's
    }

    @Test
    void opt08_optionalAtEof() {
        // Optional at end of grammar
        var result = testParse("S <- \"a\" \"b\"? ;", "a");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // 'a' matches, Optional at EOF returns empty
    }

    @Test
    void opt09_multipleOptionals() {
        // Multiple optionals in sequence
        var result = testParse("S <- \"a\"? \"b\"? \"c\" ;", "c");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // Both optionals return empty, 'c' matches
    }

    @Test
    void opt10_optionalVsZeroormore() {
        // Optional(Str(x)) vs ZeroOrMore(Str(x))
        // Optional: matches 0 or 1 time
        // ZeroOrMore: matches 0 or more times
        var opt = testParse("S <- \"x\"? \"y\" ;", "xxxy");
        // Optional matches first 'x', remaining "xxy" for rest
        // Str('y') sees "xxy", uses recovery to skip "xx", matches 'y'
        assertTrue(opt.ok(), "Optional matches 1, recovery handles rest");
        assertEquals(1, opt.errorCount(), "should have 1 error (skipped xx)");

        var zm = testParse("S <- \"x\"* \"y\" ;", "xxxy");
        assertTrue(zm.ok(), "ZeroOrMore matches all 3, then y");
        assertEquals(0, zm.errorCount(), "should have 0 errors (clean match)");
    }

    @Test
    void opt11_optionalWithComplexContent() {
        // Optional(Seq([complex structure]))
        var result = testParse(
            "S <- (\"if\" \"(\" \"x\" \")\")? \"body\" ;",
            "if(x)body"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void opt12_optionalIncompletePhase1() {
        // In Phase 1, if Optional's content is incomplete, should Optional be marked incomplete?
        // This is testing the "mark Optional fallback incomplete" (Modification 5)
        var result = testParse("S <- \"a\"? \"b\" ;", "Xb");
        // Phase 1: Optional tries 'a' at 0, sees 'X', fails
        //   Optional falls through (returns empty), marked incomplete
        // Phase 2: Re-evaluates, Optional might try recovery? Or still fall through?
        assertTrue(result.ok(), "should succeed");
        // If Optional tries recovery in Phase 2, would skip X and fail to find 'a'
        // Then falls through, 'b' matches
    }
}
