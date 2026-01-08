package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Combinators.ZeroOrMore;
import com.squirrelparser.Terminals.Str;

/**
 * ONEORMORE FIRST-ITERATION RECOVERY TESTS (FIX #10 Verification)
 * Port of oneormore_recovery_test.dart
 */
class OneOrMoreRecoveryTest {

    @Test
    void testOM01_firstClean() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "ababab");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testOM02_noMatchAnywhere() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "xyz");
        assertFalse(result.success(), "should fail (no match found)");
    }

    @Test
    void testOM03_skipToFirstMatch() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "Xab");
        assertTrue(result.success(), "should succeed (skip X on first iteration)");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("X"), "should skip X");
    }

    @Test
    void testOM04_skipMultipleToFirst() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "XXXXXab");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (entire skip)");
        assertTrue(result.skipped().contains("XXXXX"), "should skip XXXXX");
    }

    @Test
    void testOM05_multipleIterationsWithErrors() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "XabYabZab");
        assertTrue(result.success(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
        assertTrue(result.skipped().contains("X"), "should skip X");
        assertTrue(result.skipped().contains("Y"), "should skip Y");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testOM06_firstWithErrorThenClean() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "Xabababab");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (only X)");
        assertTrue(result.skipped().contains("X"), "should skip X");
    }

    @Test
    void testOM07_vsZeroormoreSemantics() {
        var zrEmpty = parse(Map.of("S", new ZeroOrMore(new Str("ab"))), "");
        assertTrue(zrEmpty.success(), "ZeroOrMore should succeed on empty input");
        assertEquals(0, zrEmpty.errorCount(), "should have 0 errors");

        var orEmpty = parse(Map.of("S", new OneOrMore(new Str("ab"))), "");
        assertFalse(orEmpty.success(), "OneOrMore should fail on empty input");

        var zrMatch = parse(Map.of("S", new ZeroOrMore(new Str("ab"))), "ababab");
        assertTrue(zrMatch.success(), "ZeroOrMore succeeds with matches");

        var orMatch = parse(Map.of("S", new OneOrMore(new Str("ab"))), "ababab");
        assertTrue(orMatch.success(), "OneOrMore succeeds with matches");
    }

    @Test
    void testOM08_longSkipPerformance() {
        var input = "X".repeat(100) + "ab";
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), input);
        assertTrue(result.success(), "should succeed (performance test)");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertEquals(100, result.skipped().get(0).length(), "should skip 100 X's");
    }

    @Test
    void testOM09_exhaustiveSearchNoMatch() {
        var input = "X".repeat(50) + "Y".repeat(50);
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), input);
        assertFalse(result.success(), "should fail (exhaustive search finds nothing)");
    }

    @Test
    void testOM10_firstIterationWithBound() {
        var result = parse(Map.of(
            "S", new Seq(new OneOrMore(new Str("ab")), new Str("end"))
        ), "XabYabend");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors (X and Y)");
        assertTrue(result.skipped().contains("X"), "should skip X");
        assertTrue(result.skipped().contains("Y"), "should skip Y");
    }

    @Test
    void testOM11_alternatingPattern() {
        var result = parse(Map.of("S", new OneOrMore(new Str("ab"))), "XabXabXabXab");
        assertTrue(result.success(), "should succeed");
        assertEquals(4, result.errorCount(), "should have 4 errors (4 X's)");
    }

    @Test
    void testOM12_multiCharTerminalFirst() {
        var result = parse(Map.of("S", new OneOrMore(new Str("hello"))), "XXXhellohello");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("XXX"), "should skip XXX");
    }
}
