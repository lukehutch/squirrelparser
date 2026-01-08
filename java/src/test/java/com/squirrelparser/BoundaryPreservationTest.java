package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Combinators.ZeroOrMore;
import com.squirrelparser.Terminals.Str;

/**
 * BOUNDARY PRESERVATION TESTS
 * Port of boundary_preservation_test.dart
 *
 * These tests verify that recovery doesn't consume content meant for
 * subsequent grammar elements (preserve structural boundaries).
 */
class BoundaryPreservationTest {

    @Test
    void testBND01_dontConsumeNextTerminal() {
        // Recovery should skip 'X' but not consume 'b' (needed by next element)
        var r = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("b"))
        ), "aXb");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skipped().contains("X"), "should skip X");
        // Verify 'b' was matched by second element, not consumed during recovery
    }

    @Test
    void testBND02_dontPartiallyConsumeNextTerminal() {
        // Multi-char terminals are atomic - recovery can't consume part of 'cd'
        var r = parse(Map.of(
            "S", new Seq(new Str("ab"), new Str("cd"))
        ), "abXcd");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skipped().contains("X"), "should skip X");
        // 'cd' should be matched atomically by second element
    }

    @Test
    void testBND03_recoveryInFirstDoesntPoisonAlternatives() {
        // First alternative fails cleanly, second succeeds
        var r = parse(Map.of(
            "S", new First(
                new Seq(new Str("a"), new Str("b")),
                new Seq(new Str("c"), new Str("d"))
            )
        ), "cd");
        assertTrue(r.success(), "should succeed (second alternative)");
        assertEquals(0, r.errorCount(), "should have 0 errors (clean match)");
    }

    @Test
    void testBND04_firstAlternativeWithRecoveryVsSecondClean() {
        // First alternative needs recovery, second is clean
        // Should prefer first (longer match, see FIX #2)
        var r = parse(Map.of(
            "S", new First(
                new Seq(new Str("a"), new Str("b"), new Str("c")),
                new Str("a")
            )
        ), "aXbc");
        assertTrue(r.success(), "should succeed");
        // FIX #2: Prefer longer matches over fewer errors
        assertEquals(1, r.errorCount(),
            "should choose first alternative (longer despite error)");
    }

    @Test
    void testBND05_boundaryWithNestedRepetition() {
        // Repetition with bound should stop at delimiter
        var r = parse(Map.of(
            "S", new Seq(new OneOrMore(new Str("x")), new Str(";"), new OneOrMore(new Str("y")))
        ), "xxx;yyy");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
        // x+ stops at ';', y+ stops at EOF
    }

    @Test
    void testBND06_boundaryWithRecoveryBeforeDelimiter() {
        // Recovery happens, but delimiter is preserved
        var r = parse(Map.of(
            "S", new Seq(new OneOrMore(new Str("x")), new Str(";"), new OneOrMore(new Str("y")))
        ), "xxXx;yyy");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skipped().contains("X"), "should skip X");
        // ';' should not be consumed during recovery of x+
    }

    @Test
    void testBND07_probeRespectsBoundaries() {
        // ZeroOrMore probes ahead to find boundary
        var r = parse(Map.of(
            "S", new Seq(
                new ZeroOrMore(new Str("x")),
                new First(new Str("y"), new Str("z"))
            )
        ), "xxxz");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
        // ZeroOrMore should probe, find 'z' matches First, stop before it
    }

    @Test
    void testBND08_complexBoundaryNesting() {
        // Nested sequences with multiple boundaries
        var r = parse(Map.of(
            "S", new Seq(
                new Seq(new OneOrMore(new Str("a")), new Str("+")),
                new Seq(new OneOrMore(new Str("b")), new Str("="))
            )
        ), "aaa+bbb=");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
        // Each repetition stops at its delimiter
    }

    @Test
    void testBND09_boundaryWithEOF() {
        // No explicit boundary - should consume until EOF
        var r = parse(Map.of("S", new OneOrMore(new Str("x"))), "xxxxx");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
        // Consumes all x's (no boundary to stop at)
    }

    @Test
    void testBND10_recoveryNearBoundary() {
        // Error just before boundary - should not cross boundary
        var r = parse(Map.of(
            "S", new Seq(new OneOrMore(new Str("x")), new Str(";"))
        ), "xxX;");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skipped().contains("X"), "should skip X");
        // ';' should remain for second element
    }
}
