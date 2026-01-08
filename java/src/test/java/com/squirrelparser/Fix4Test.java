package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.Str;

/**
 * SECTION 4: FIX #4 - MULTI-LEVEL BOUNDED RECOVERY (17 tests)
 * Port of fix4_test.dart
 */
class Fix4Test {

    @Test
    void testF4_L1_01_Clean2() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), "(xx)(xx)");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testF4_L1_02_Clean5() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), "(xx)(xx)(xx)(xx)(xx)");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testF4_L1_03_ErrFirst() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), "(xZx)(xx)");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF4_L1_04_ErrMid() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), "(xx)(xZx)(xx)");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF4_L1_05_ErrLast() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), "(xx)(xZx)");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF4_L1_06_ErrAll3() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), "(xAx)(xBx)(xCx)");
        assertTrue(result.success(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
        assertTrue(result.skipped().contains("A") &&
                   result.skipped().contains("B") &&
                   result.skipped().contains("C"),
            "should skip A, B, C");
    }

    @Test
    void testF4_L1_07_Boundary() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), "(xx)Z(xx)");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF4_L1_08_LongBoundary() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), "(xx)ZZZ(xx)");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("ZZZ"), "should skip ZZZ");
    }

    @Test
    void testF4_L2_01_Clean() {
        var result = parse(Map.of(
            "S", new Seq(
                new Str("{"),
                new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")"))),
                new Str("}")
            )
        ), "{(xx)(xx)}");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testF4_L2_02_ErrInner() {
        var result = parse(Map.of(
            "S", new Seq(
                new Str("{"),
                new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")"))),
                new Str("}")
            )
        ), "{(xx)(xZx)}");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF4_L2_03_ErrOuter() {
        var result = parse(Map.of(
            "S", new Seq(
                new Str("{"),
                new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")"))),
                new Str("}")
            )
        ), "{(xx)Z(xx)}");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF4_L2_04_BothLevels() {
        var result = parse(Map.of(
            "S", new Seq(
                new Str("{"),
                new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")"))),
                new Str("}")
            )
        ), "{(xAx)B(xCx)}");
        assertTrue(result.success(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
    }

    @Test
    void testF4_L3_01_Clean() {
        var result = parse(Map.of(
            "S", new Seq(
                new Str("["),
                new Seq(
                    new Str("{"),
                    new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")"))),
                    new Str("}")
                ),
                new Str("]")
            )
        ), "[{(xx)(xx)}]");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testF4_L3_02_ErrDeepest() {
        var result = parse(Map.of(
            "S", new Seq(
                new Str("["),
                new Seq(
                    new Str("{"),
                    new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")"))),
                    new Str("}")
                ),
                new Str("]")
            )
        ), "[{(xx)(xZx)}]");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF4_N1_10Groups() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), "(xx)(xx)(xx)(xx)(xx)(xx)(xx)(xx)(xx)(xx)");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testF4_N2_10Groups5Err() {
        String input = IntStream.range(0, 10)
            .mapToObj(i -> i % 2 == 0 ? "(xZx)" : "(xx)")
            .collect(Collectors.joining());
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), input);
        assertTrue(result.success(), "should succeed");
        assertEquals(5, result.errorCount(), "should have 5 errors");
    }

    @Test
    void testF4_N3_20Groups() {
        String input = "(xx)".repeat(20);
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), input);
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }
}
