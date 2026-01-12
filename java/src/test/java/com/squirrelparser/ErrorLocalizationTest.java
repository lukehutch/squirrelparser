// ===========================================================================
// ERROR LOCALIZATION TESTS (Non-Cascading Verification)
// ===========================================================================
// These tests verify that errors don't cascade - each error is localized
// to its specific location without affecting subsequent parsing.

package com.squirrelparser;

import org.junit.jupiter.api.Test;

import static com.squirrelparser.TestUtils.*;
import static org.junit.jupiter.api.Assertions.*;

class ErrorLocalizationTest {

    @Test
    void cascade01_errorInFirstElementDoesntAffectSecond() {
        // Error in first element, second element parses cleanly
        String grammar = "S <- \"a\" \"b\" \"c\" ;";
        var result = testParse(grammar, "aXbc");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have exactly 1 error (at position 1)");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        // Error localized to position 1, doesn't cascade to 'b' or 'c'
    }

    @Test
    void cascade02_errorInNestedStructure() {
        // Error inside inner Seq, doesn't affect outer Seq
        String grammar = """
            S <- ("a" "b") "c" ;
        """;
        var result = testParse(grammar, "aXbc");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have exactly 1 error");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        // Error in inner Seq (between 'a' and 'b'), outer Seq continues normally
    }

    @Test
    void cascade03_lrErrorDoesntCascadeToNextExpansion() {
        // Error in one LR expansion iteration, next iteration clean
        String grammar = """
            E <- E "+" "n" / "n" ;
        """;
        var result = testParse(grammar, "n+Xn+n", "E");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have exactly 1 error");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        // Expansion: n (base), n+[skip X]n, n+Xn+n
        // First '+' clean, second '+' has error, third '+' clean
        // Error localized to second iteration
    }

    @Test
    void cascade04_multipleIndependentErrors() {
        // Multiple errors in different parts of parse, all localized
        String grammar = """
            S <- ("a" "b") ("c" "d") ("e" "f") ;
        """;
        var result = testParse(grammar, "aXbcYdeZf");
        assertTrue(result.ok(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 independent errors");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        assertTrue(result.skippedStrings().contains("Y"), "should skip Y");
        assertTrue(result.skippedStrings().contains("Z"), "should skip Z");
        // Each error localized to its respective Seq
    }

    @Test
    void cascade05_errorBeforeRepetition() {
        // Error before repetition, repetition parses cleanly
        String grammar = """
            S <- "a" "b"+ ;
        """;
        var result = testParse(grammar, "aXbbb");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        // Error at position 1, OneOrMore starts cleanly at position 2
    }

    @Test
    void cascade06_errorAfterRepetition() {
        // Repetition clean, error after it
        String grammar = """
            S <- "a"+ "b" ;
        """;
        var result = testParse(grammar, "aaaXb");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        // OneOrMore matches 3 a's cleanly, then error, then 'b'
    }

    @Test
    void cascade07_errorInFirstAlternativeDoesntPoisonSecond() {
        // First alternative has error, second alternative clean
        String grammar = """
            S <- "a" "b" / "c" ;
        """;
        var result = testParse(grammar, "c");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors (second alternative clean)");
        // First tries and fails, second succeeds cleanly - no cascade
    }

    @Test
    void cascade08_recoveryVersionIncrementsCorrectly() {
        // Each recovery increments version, ensuring proper cache invalidation
        String grammar = """
            S <- ("a" "b") ("c" "d") ;
        """;
        var result = testParse(grammar, "aXbcYd");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
        // Two recoveries, each increments version, no cache pollution
    }

    @Test
    void cascade09_errorAtDeeplyNestedLevel() {
        // Error very deep in nesting, doesn't affect outer levels
        String grammar = """
            S <- ((("a" "b") "c") "d") "e" ;
        """;
        var result = testParse(grammar, "aXbcde");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error at deepest level");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        // Error localized despite 4 levels of nesting
    }

    @Test
    void cascade10_errorRecoveryDoesntLeaveParserInBadState() {
        // After recovery, parser continues with clean state
        String grammar = """
            S <- ("a" "b") "c" ("d" "e") ;
        """;
        var result = testParse(grammar, "abXcde");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        // After skipping X at position 2, matches 'c' at position 3, then 'de'
    }
}
