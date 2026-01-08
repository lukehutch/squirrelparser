package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Combinators.ZeroOrMore;
import com.squirrelparser.Terminals.Str;

/**
 * SECTION 6: REPETITION COMPREHENSIVE (25 tests)
 * Port of repetition_test.dart
 */
class RepetitionTest {

    @Test
    void testR01_between() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "abXXab");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("XX"), "should skip XX");
    }

    @Test
    void testR02_multi() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "abXabYab");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
        assertTrue(result.skipped().contains("X") && result.skipped().contains("Y"),
            "should skip X and Y");
    }

    @Test
    void testR03_longSkip() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "ab" + "X".repeat(50) + "ab");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
    }

    @Test
    void testR04_ZeroOrMoreStart() {
        var result = parse(Map.of(
            "S", new Seq(new ZeroOrMore(new Str("ab")), new Str("!"))
        ), "XXab!");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("XX"), "should skip XX");
    }

    @Test
    void testR05_beforeFirst() {
        // FIX #10: OneOrMore now allows first-iteration recovery
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "XXab");
        assertTrue(result.success(), "should succeed (skip XX on first iteration)");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("XX"), "should skip XX");
    }

    @Test
    void testR06_trailingFail() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "ababXX");
        assertFalse(result.success(), "should fail (trailing error)");
    }

    @Test
    void testR07_single() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "ab");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testR08_ZeroOrMoreEmpty() {
        var result = parse(Map.of("S", new ZeroOrMore(new Str("ab"))), "");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testR09_alternating() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "abXabXabXab");
        assertTrue(result.success(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
    }

    @Test
    void testR10_longClean() {
        var result = parse(Map.of("S", new OneOrMore(new Str("x"))), "x".repeat(100));
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testR11_longErr() {
        var result = parse(Map.of("S", new OneOrMore(new Str("x"))), "x".repeat(50) + "Z" + "x".repeat(49));
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testR12_20errors() {
        var input = "abZ".repeat(20) + "ab";
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), input);
        assertTrue(result.success(), "should succeed");
        assertEquals(20, result.errorCount(), "should have 20 errors");
    }

    @Test
    void testR13_veryLong() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "ab".repeat(500));
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testR14_veryLongErr() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "ab".repeat(250) + "ZZ" + "ab".repeat(249));
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
    }

    @Test
    void testR15_trailingSingleCharAfterRecovery() {
        var result = parse(
            Map.of("S", new Ref("A"), "A", new OneOrMore(new First(new Str("a"), new Str("b")))),
            "abxbxax"
        );
        assertTrue(result.success(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
        assertEquals(3, result.skipped().size(), "should have 3 skipped items");
    }

    @Test
    void testR16_trailingMultipleCharsAfterRecovery() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "abXabXabXX");
        assertTrue(result.success(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
        assertEquals(3, result.skipped().size(), "should have 3 skipped items");
    }

    @Test
    void testR17_trailingLongErrorAfterRecovery() {
        var result = parse(
            Map.of("S", new OneOrMore(new Str("x"))),
            "x".repeat(50) + "Z" + "x".repeat(49) + "YYYY"
        );
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
    }

    @Test
    void testR18_trailingAfterMultipleAlternatingErrors() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "abXabYabZabXX");
        assertTrue(result.success(), "should succeed");
        assertEquals(4, result.errorCount(), "should have 4 errors");
        assertEquals(4, result.skipped().size(), "should have 4 skipped items");
    }

    @Test
    void testR19_singleCharAfterFirstRecovery() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "XXabX");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
        assertEquals(2, result.skipped().size(), "should have 2 skipped items");
    }

    @Test
    void testR20_trailingErrorWithSingleElement() {
        var result = parse(Map.of("S", new OneOrMore(new Str("a"))), "aXaY");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
        assertEquals(2, result.skipped().size(), "should have 2 skipped items");
    }
}
