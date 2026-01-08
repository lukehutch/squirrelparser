package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Combinators.ZeroOrMore;
import com.squirrelparser.Terminals.Str;

/**
 * REPETITION EDGE CASE TESTS
 * Port of repetition_edge_case_test.dart
 */
class RepetitionEdgeCaseTest {

    @Test
    void testREP01_zeroormoreEmptyMatch() {
        var result = parse(Map.of(
            "S", new Seq(new ZeroOrMore(new Str("x")), new Str("y"))
        ), "y");
        assertTrue(result.success(), "should succeed (ZeroOrMore matches 0)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testREP02_oneormoreVsZeroormoreAtEof() {
        var om = parse(Map.of("S", new OneOrMore(new Str("x"))), "");
        assertFalse(om.success(), "OneOrMore should fail on empty input");

        var zm = parse(Map.of("S", new ZeroOrMore(new Str("x"))), "");
        assertTrue(zm.success(), "ZeroOrMore should succeed on empty input");
    }

    @Test
    void testREP03_nestedRepetition() {
        var result = parse(Map.of("S", new OneOrMore(new OneOrMore(new Str("x")))), "xxxXxxXxxx");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors (two X gaps)");
    }

    @Test
    void testREP04_repetitionWithRecoveryHitsBound() {
        var result = parse(Map.of(
            "S", new Seq(new OneOrMore(new Str("x")), new Str("end"))
        ), "xXxXxend");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
        assertEquals(2, result.skipped().size(), "should skip 2 X's");
    }

    @Test
    void testREP05_repetitionRecoveryVsProbe() {
        var result = parse(Map.of(
            "S", new Seq(new ZeroOrMore(new Str("x")), new Str("y"))
        ), "xxxy");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testREP06_alternatingMatchSkipPattern() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "abXabXabXab");
        assertTrue(result.success(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors (3 X's)");
    }

    @Test
    void testREP07_repetitionOfComplexStructure() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("a"), new Str("b")))
        ), "ababab");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testREP08_repetitionStopsOnNonMatch() {
        var result = parse(Map.of(
            "S", new Seq(new OneOrMore(new Str("x")), new Str("y"))
        ), "xxxy");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testREP09_repetitionWithFirstAlternative() {
        var result = parse(Map.of(
            "S", new OneOrMore(new First(new Str("a"), new Str("b")))
        ), "aabba");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testREP10_zeroormoreWithRecoveryInside() {
        var result = parse(Map.of(
            "S", new ZeroOrMore(new Seq(new Str("a"), new Str("b")))
        ), "abXaYb");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
    }

    @Test
    void testREP11_greedyVsNonGreedy() {
        var result = parse(Map.of(
            "S", new Seq(new ZeroOrMore(new Str("x")), new Str("y"), new Str("z"))
        ), "xxxxxyz");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testREP12_repetitionAtEofWithDeletion() {
        var result = parse(Map.of(
            "S", new Seq(new Str("a"), new OneOrMore(new Str("b")))
        ), "a");
        assertTrue(result.success(), "should succeed (delete b+ at EOF)");
    }

    @Test
    void testREP13_veryLongRepetition() {
        var input = "x".repeat(1000);
        var result = parse(Map.of("S", new OneOrMore(new Str("x"))), input);
        assertTrue(result.success(), "should succeed (1000 iterations)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testREP14_repetitionWithManyErrors() {
        var input = "Xx".repeat(100);
        var result = parse(Map.of("S", new OneOrMore(new Str("x"))), input);
        assertTrue(result.success(), "should succeed");
        assertEquals(100, result.errorCount(), "should have 100 errors");
    }

    @Test
    void testREP15_nestedZeoormore() {
        var result = parse(Map.of(
            "S", new Seq(new ZeroOrMore(new ZeroOrMore(new Str("x"))), new Str("y"))
        ), "y");
        assertTrue(result.success(), "should succeed (both match 0)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }
}
