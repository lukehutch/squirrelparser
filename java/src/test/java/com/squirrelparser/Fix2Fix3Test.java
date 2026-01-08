package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.Str;

/**
 * SECTION 3: FIX #2/#3 - CACHE INTEGRITY (10 tests)
 * Port of fix2_fix3_test.dart
 */
class Fix2Fix3Test {

    @Test
    void testF2_01_BasicProbe() {
        var result = parse(Map.of(
            "S", new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")"))
        ), "(xZZx)");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("ZZ"), "should skip ZZ");
    }

    @Test
    void testF2_02_DoubleProbe() {
        var result = parse(Map.of(
            "S", new Seq(
                new Str("a"),
                new OneOrMore(new Str("x")),
                new Str("b"),
                new OneOrMore(new Str("y")),
                new Str("c")
            )
        ), "axXxbyYyc");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
    }

    @Test
    void testF2_03_ProbeSameClause() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), "(xZx)(xYx)");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
        assertTrue(result.skipped().contains("Z") && result.skipped().contains("Y"),
            "should skip Z and Y");
    }

    @Test
    void testF2_04_TripleGroup() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("["), new OneOrMore(new Str("x")), new Str("]")))
        ), "[xAx][xBx][xCx]");
        assertTrue(result.success(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
    }

    @Test
    void testF2_05_FiveGroups() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), "(xAx)(xBx)(xCx)(xDx)(xEx)");
        assertTrue(result.success(), "should succeed");
        assertEquals(5, result.errorCount(), "should have 5 errors");
    }

    @Test
    void testF2_06_AlternatingCleanErr() {
        var result = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), "(xx)(xZx)(xx)(xYx)(xx)");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors");
    }

    @Test
    void testF2_07_LongInnerError() {
        var result = parse(Map.of(
            "S", new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")"))
        ), "(x" + "Z".repeat(20) + "x)");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
    }

    @Test
    void testF2_08_NestedProbe() {
        var result = parse(Map.of(
            "S", new Seq(
                new Str("{"),
                new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")),
                new Str("}")
            )
        ), "{(xZx)}");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF2_09_TripleNested() {
        var result = parse(Map.of(
            "S", new Seq(
                new Str("<"),
                new Seq(
                    new Str("{"),
                    new Seq(new Str("["), new OneOrMore(new Str("x")), new Str("]")),
                    new Str("}")
                ),
                new Str(">")
            )
        ), "<{[xZx]}>");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF2_10_RefProbe() {
        var result = parse(Map.of(
            "S", new Seq(new Str("("), new Ref("R"), new Str(")")),
            "R", new OneOrMore(new Str("x"))
        ), "(xZx)");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }
}
