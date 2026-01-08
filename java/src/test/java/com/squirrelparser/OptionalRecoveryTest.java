package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Optional;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Combinators.ZeroOrMore;
import com.squirrelparser.Terminals.Str;

/**
 * OPTIONAL WITH RECOVERY TESTS
 * Port of optional_recovery_test.dart
 */
class OptionalRecoveryTest {

    @Test
    void testOPT01_optionalMatchesCleanly() {
        var result = parse(Map.of(
            "S", new Seq(new Optional(new Str("a")), new Str("b"))
        ), "ab");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testOPT02_optionalFallsThroughCleanly() {
        var result = parse(Map.of(
            "S", new Seq(new Optional(new Str("a")), new Str("b"))
        ), "b");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testOPT03_optionalWithRecoveryAttempt() {
        var result = parse(Map.of(
            "S", new Optional(new Seq(new Str("a"), new Str("b")))
        ), "aXb");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "Optional should attempt recovery");
        assertTrue(result.skipped().contains("X"), "should skip X");
    }

    @Test
    void testOPT04_optionalInSequence() {
        var result = parse(Map.of(
            "S", new Seq(new Str("a"), new Optional(new Str("b")), new Str("c"))
        ), "ac");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testOPT05_nestedOptional() {
        var result = parse(Map.of(
            "S", new Seq(new Optional(new Optional(new Str("a"))), new Str("b"))
        ), "b");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testOPT06_optionalWithFirst() {
        var result = parse(Map.of(
            "S", new Seq(
                new Optional(new First(new Str("a"), new Str("b"))),
                new Str("c")
            )
        ), "bc");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testOPT07_optionalWithRepetition() {
        var result = parse(Map.of(
            "S", new Seq(new Optional(new OneOrMore(new Str("x"))), new Str("y"))
        ), "xxxy");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testOPT08_optionalAtEof() {
        var result = parse(Map.of(
            "S", new Seq(new Str("a"), new Optional(new Str("b")))
        ), "a");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testOPT09_multipleOptionals() {
        var result = parse(Map.of(
            "S", new Seq(new Optional(new Str("a")), new Optional(new Str("b")), new Str("c"))
        ), "c");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testOPT10_optionalVsZerormore() {
        var opt = parse(Map.of(
            "S", new Seq(new Optional(new Str("x")), new Str("y"))
        ), "xxxy");
        assertTrue(opt.success(), "Optional matches 1, recovery handles rest");
        assertEquals(1, opt.errorCount(), "should have 1 error (skipped xx)");

        var zm = parse(Map.of(
            "S", new Seq(new ZeroOrMore(new Str("x")), new Str("y"))
        ), "xxxy");
        assertTrue(zm.success(), "ZeroOrMore matches all 3, then y");
        assertEquals(0, zm.errorCount(), "should have 0 errors (clean match)");
    }

    @Test
    void testOPT11_optionalWithComplexContent() {
        var result = parse(Map.of(
            "S", new Seq(
                new Optional(new Seq(new Str("if"), new Str("("), new Str("x"), new Str(")"))),
                new Str("body")
            )
        ), "if(x)body");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testOPT12_optionalIncompletePhase1() {
        var result = parse(Map.of(
            "S", new Seq(new Optional(new Str("a")), new Str("b"))
        ), "Xb");
        assertTrue(result.success(), "should succeed");
    }
}
