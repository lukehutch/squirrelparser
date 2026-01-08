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
import com.squirrelparser.Terminals.CharRange;
import com.squirrelparser.Terminals.Str;

/**
 * SECTION 9: LEFT RECURSION (10 tests)
 * Port of lr_test.dart
 */
class LRTest {

    private static final Map<String, Clause> lr1 = Map.of(
        "S", new First(
            new Seq(new Ref("S"), new Str("+"), new Ref("T")),
            new Ref("T")
        ),
        "T", new OneOrMore(new CharRange("0", "9"))
    );

    @Test
    void testLR01_simple() {
        var result = parse(lr1, "1+2+3");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testLR02_single() {
        var result = parse(lr1, "42");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testLR03_chain5() {
        var input = String.join("+", "1", "1", "1", "1", "1");
        var result = parse(lr1, input);
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testLR04_chain10() {
        var input = String.join("+", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1");
        var result = parse(lr1, input);
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    private static final Map<String, Clause> expr = Map.of(
        "S", new Ref("E"),
        "E", new First(
            new Seq(new Ref("E"), new Str("+"), new Ref("T")),
            new Ref("T")
        ),
        "T", new First(
            new Seq(new Ref("T"), new Str("*"), new Ref("F")),
            new Ref("F")
        ),
        "F", new First(
            new Seq(new Str("("), new Ref("E"), new Str(")")),
            new CharRange("0", "9")
        )
    );

    @Test
    void testLR05_withMult() {
        var result = parse(expr, "1+2*3");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testLR06_parens() {
        var result = parse(expr, "(1+2)*3");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testLR07_nestedParens() {
        var result = parse(expr, "((1+2))");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testLR08_direct() {
        var result = parse(Map.of(
            "S", new First(
                new Seq(new Ref("S"), new Str("x")),
                new Str("y")
            )
        ), "yxxx");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testLR09_multiDigit() {
        var result = parse(lr1, "12+345+6789");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testLR10_complexExpr() {
        var result = parse(expr, "1+2*3+4*5");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }
}
