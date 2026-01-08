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
 * SECTION 2: FIX #1 - isComplete PROPAGATION (15 tests)
 * Port of fix1_test.dart
 */
class Fix1Test {

    @Test
    void testF1_01_RepSeqBasic() {
        var result = parse(Map.of(
            "S", new Seq(new OneOrMore(new Str("ab")), new Str("!"))
        ), "abXXab!");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error, got " + result.errorCount());
        assertTrue(result.skipped().stream().anyMatch(s -> s.contains("XX")), "should skip XX");
    }

    @Test
    void testF1_02_RepOptional() {
        var result = parse(Map.of(
            "S", new Seq(new OneOrMore(new Str("ab")), new Optional(new Str("!")))
        ), "abXXab");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().stream().anyMatch(s -> s.contains("XX")), "should skip XX");
    }

    @Test
    void testF1_03_RepOptionalMatch() {
        var result = parse(Map.of(
            "S", new Seq(new OneOrMore(new Str("ab")), new Optional(new Str("!")))
        ), "abXXab!");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().stream().anyMatch(s -> s.contains("XX")), "should skip XX");
    }

    @Test
    void testF1_04_FirstWrapping() {
        var result = parse(Map.of(
            "S", new First(new Seq(new OneOrMore(new Str("ab")), new Str("!")))
        ), "abXXab!");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
    }

    @Test
    void testF1_05_NestedSeqL1() {
        var result = parse(Map.of(
            "S", new Seq(new Seq(new OneOrMore(new Str("x"))))
        ), "xZx");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF1_06_NestedSeqL2() {
        var result = parse(Map.of(
            "S", new Seq(new Seq(new Seq(new OneOrMore(new Str("x")))))
        ), "xZx");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF1_07_NestedSeqL3() {
        var result = parse(Map.of(
            "S", new Seq(new Seq(new Seq(new Seq(new OneOrMore(new Str("x"))))))
        ), "xZx");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF1_08_OptionalWrapping() {
        var result = parse(Map.of(
            "S", new Optional(new Seq(new OneOrMore(new Str("x"))))
        ), "xZx");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF1_09_ZeroOrMoreInSeq() {
        var result = parse(Map.of(
            "S", new Seq(new ZeroOrMore(new Str("ab")), new Str("!"))
        ), "abXXab!");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().stream().anyMatch(s -> s.contains("XX")), "should skip XX");
    }

    @Test
    void testF1_10_MultipleReps() {
        var result = parse(Map.of(
            "S", new Seq(new OneOrMore(new Str("a")), new OneOrMore(new Str("b")))
        ), "aXabYb");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
    }

    @Test
    void testF1_11_RepRepTerm() {
        var result = parse(Map.of(
            "S", new Seq(new OneOrMore(new Str("a")), new OneOrMore(new Str("b")), new Str("!"))
        ), "aXabYb!");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
    }

    @Test
    void testF1_12_LongErrorSpan() {
        var result = parse(Map.of(
            "S", new Seq(new OneOrMore(new Str("x")), new Str("!"))
        ), "x" + "Z".repeat(20) + "x!");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
    }

    @Test
    void testF1_13_MultipleLongErrors() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Str("ab"))
        ), "ab" + "X".repeat(10) + "ab" + "Y".repeat(10) + "ab");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
    }

    @Test
    void testF1_14_InterspersedErrors() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Str("ab"))
        ), "abXabYabZab");
        assertTrue(result.success(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
    }

    @Test
    void testF1_15_FiveErrors() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Str("ab"))
        ), "abAabBabCabDabEab");
        assertTrue(result.success(), "should succeed");
        assertEquals(5, result.errorCount(), "should have 5 errors");
    }
}
