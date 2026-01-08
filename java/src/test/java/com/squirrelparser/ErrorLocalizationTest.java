package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.Str;

/**
 * ERROR LOCALIZATION TESTS (Non-Cascading Verification)
 * Port of error_localization_test.dart
 */
class ErrorLocalizationTest {

    @Test
    void testCASCADE01_errorInFirstElementDoesntAffectSecond() {
        var result = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("b"), new Str("c"))
        ), "aXbc");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have exactly 1 error (at position 1)");
        assertTrue(result.skipped().contains("X"), "should skip X");
    }

    @Test
    void testCASCADE02_errorInNestedStructure() {
        var result = parse(Map.of(
            "S", new Seq(
                new Seq(new Str("a"), new Str("b")),
                new Str("c")
            )
        ), "aXbc");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have exactly 1 error");
        assertTrue(result.skipped().contains("X"), "should skip X");
    }

    @Test
    void testCASCADE03_lrErrorDoesntCascadeToNextExpansion() {
        var result = parse(Map.of(
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            )
        ), "n+Xn+n", "E");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have exactly 1 error");
        assertTrue(result.skipped().contains("X"), "should skip X");
    }

    @Test
    void testCASCADE04_multipleIndependentErrors() {
        var result = parse(Map.of(
            "S", new Seq(
                new Seq(new Str("a"), new Str("b")),
                new Seq(new Str("c"), new Str("d")),
                new Seq(new Str("e"), new Str("f"))
            )
        ), "aXbcYdeZf");
        assertTrue(result.success(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 independent errors");
        assertTrue(result.skipped().contains("X"), "should skip X");
        assertTrue(result.skipped().contains("Y"), "should skip Y");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testCASCADE05_errorBeforeRepetition() {
        var result = parse(Map.of(
            "S", new Seq(new Str("a"), new OneOrMore(new Str("b")))
        ), "aXbbb");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("X"), "should skip X");
    }

    @Test
    void testCASCADE06_errorAfterRepetition() {
        var result = parse(Map.of(
            "S", new Seq(new OneOrMore(new Str("a")), new Str("b"))
        ), "aaaXb");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("X"), "should skip X");
    }

    @Test
    void testCASCADE07_errorInFirstAlternativeDoesntPoisonSecond() {
        var result = parse(Map.of(
            "S", new First(
                new Seq(new Str("a"), new Str("b")),
                new Str("c")
            )
        ), "c");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors (second alternative clean)");
    }

    @Test
    void testCASCADE08_recoveryVersionIncrementsCorrectly() {
        var result = parse(Map.of(
            "S", new Seq(
                new Seq(new Str("a"), new Str("b")),
                new Seq(new Str("c"), new Str("d"))
            )
        ), "aXbcYd");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
    }

    @Test
    void testCASCADE09_errorAtDeeplyNestedLevel() {
        var result = parse(Map.of(
            "S", new Seq(
                new Seq(
                    new Seq(
                        new Seq(new Str("a"), new Str("b")),
                        new Str("c")
                    ),
                    new Str("d")
                ),
                new Str("e")
            )
        ), "aXbcde");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error at deepest level");
        assertTrue(result.skipped().contains("X"), "should skip X");
    }

    @Test
    void testCASCADE10_errorRecoveryDoesntLeaveParserInBadState() {
        var result = parse(Map.of(
            "S", new Seq(
                new Seq(new Str("a"), new Str("b")),
                new Str("c"),
                new Seq(new Str("d"), new Str("e"))
            )
        ), "abXcde");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
    }
}
