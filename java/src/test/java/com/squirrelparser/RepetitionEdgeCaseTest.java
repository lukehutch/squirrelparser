// ===========================================================================
// REPETITION EDGE CASE TESTS
// ===========================================================================
// These tests verify edge cases in repetition handling including nested
// repetitions, probe mechanics, and boundary interactions.

package com.squirrelparser;

import org.junit.jupiter.api.Test;

import static com.squirrelparser.TestUtils.*;
import static org.junit.jupiter.api.Assertions.*;

class RepetitionEdgeCaseTest {

    @Test
    void rep01_zeroormoreEmptyMatch() {
        // ZeroOrMore can match zero times
        var result = testParse("S <- \"x\"* \"y\" ;", "y");
        assertTrue(result.ok(), "should succeed (ZeroOrMore matches 0)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void rep02_oneormoreVsZeroormoreAtEof() {
        // OneOrMore requires at least one match, ZeroOrMore doesn't
        var om = testParse("S <- \"x\"+ ;", "");
        assertFalse(om.ok(), "OneOrMore should fail on empty input");

        var zm = testParse("S <- \"x\"* ;", "");
        assertTrue(zm.ok(), "ZeroOrMore should succeed on empty input");
    }

    @Test
    void rep03_nestedRepetition() {
        // OneOrMore(OneOrMore(x)) - nested repetitions
        var result = testParse("S <- (\"x\"+)+ ;", "xxxXxxXxxx");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors (two X gaps)");
        // Outer: matches 3 times (group1, skip X, group2, skip X, group3)
        // Each group is inner OneOrMore matching x's
    }

    @Test
    void rep04_repetitionWithRecoveryHitsBound() {
        // Repetition with recovery, encounters bound
        var result = testParse("S <- \"x\"+ \"end\" ;", "xXxXxend");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
        assertEquals(2, result.skippedStrings().size(), "should skip 2 X's");
        // Repetition stops before 'end' (bound)
    }

    @Test
    void rep05_repetitionRecoveryVsProbe() {
        // ZeroOrMore must probe ahead to avoid consuming boundary
        var result = testParse("S <- \"x\"* \"y\" ;", "xxxy");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // ZeroOrMore should match all x's, stop before 'y'
    }

    @Test
    void rep06_alternatingMatchSkipPattern() {
        // Pattern: match, skip, match, skip, ...
        var result = testParse("S <- \"ab\"+ ;", "abXabXabXab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors (3 X's)");
    }

    @Test
    void rep07_repetitionOfComplexStructure() {
        // OneOrMore(Seq([...])) - repetition of sequences
        var result = testParse("S <- (\"a\" \"b\")+ ;", "ababab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // Matches 3 times: (a,b), (a,b), (a,b)
    }

    @Test
    void rep08_repetitionStopsOnNonMatch() {
        // Repetition stops when element no longer matches
        var result = testParse("S <- \"x\"+ \"y\" ;", "xxxy");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // OneOrMore matches 3 x's, stops, then 'y' matches
    }

    @Test
    void rep09_repetitionWithFirstAlternative() {
        // OneOrMore(First([...])) - repetition of alternatives
        var result = testParse("S <- (\"a\" / \"b\")+ ;", "aabba");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // Matches 5 times: a, a, b, b, a
    }

    @Test
    void rep10_zeroormoreWithRecoveryInside() {
        // ZeroOrMore element needs recovery
        var result = testParse("S <- (\"a\" \"b\")* ;", "abXaYb");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
        // First iteration: a, b (clean)
        // Second iteration: Seq needs recovery
        //   Within Seq: 'a' expects 'a' at pos 2, sees 'X', skip X, match 'a' at pos 3
        //   Then 'b' expects 'b' at pos 4, sees 'Y', skip Y, match 'b' at pos 5
        // So yes, 2 errors total
    }

    @Test
    void rep11_greedyVsNonGreedy() {
        // Repetitions are greedy - match as many as possible
        var result = testParse("S <- \"x\"* \"y\" \"z\" ;", "xxxxxyz");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // ZeroOrMore is greedy, matches all x's, then y and z
    }

    @Test
    void rep12_repetitionAtEofWithDeletion() {
        // Repetition at EOF can have grammar deletion (completion)
        var result = testParse("S <- \"a\" \"b\"+ ;", "a");
        assertTrue(result.ok(), "should succeed (delete b+ at EOF)");
        // At EOF, can delete the OneOrMore requirement
    }

    @Test
    void rep13_veryLongRepetition() {
        // Performance test: many iterations
        var input = "x".repeat(1000);
        var result = testParse("S <- \"x\"+ ;", input);
        assertTrue(result.ok(), "should succeed (1000 iterations)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void rep14_repetitionWithManyErrors() {
        // Many errors within repetition
        var sb = new StringBuilder();
        for (int i = 0; i < 100; i++) {
            sb.append("Xx");
        }
        var result = testParse("S <- \"x\"+ ;", sb.toString());
        assertTrue(result.ok(), "should succeed");
        assertEquals(100, result.errorCount(), "should have 100 errors");
    }

    @Test
    void rep15_nestedZeroormore() {
        // ZeroOrMore(ZeroOrMore(...)) - both can match zero
        var result = testParse("S <- (\"x\"*)* \"y\" ;", "y");
        assertTrue(result.ok(), "should succeed (both match 0)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }
}
