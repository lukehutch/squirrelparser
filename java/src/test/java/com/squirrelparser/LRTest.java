// ===========================================================================
// SECTION 9: LEFT RECURSION (10 tests)
// ===========================================================================

package com.squirrelparser;

import org.junit.jupiter.api.Test;

import java.util.Collections;

import static org.junit.jupiter.api.Assertions.*;
import static com.squirrelparser.TestUtils.*;

class LRTest {
    private static final String LR1 = """
        S <- S "+" T / T ;
        T <- [0-9]+ ;
    """;

    private static final String EXPR = """
        S <- E ;
        E <- E "+" T / T ;
        T <- T "*" F / F ;
        F <- "(" E ")" / [0-9] ;
    """;

    @Test
    void lr01_simple() {
        var result = testParse(LR1, "1+2+3");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void lr02_single() {
        var result = testParse(LR1, "42");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void lr03_chain5() {
        var result = testParse(LR1, String.join("+", Collections.nCopies(5, "1")));
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void lr04_chain10() {
        var result = testParse(LR1, String.join("+", Collections.nCopies(10, "1")));
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void lr05_withMult() {
        var result = testParse(EXPR, "1+2*3");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void lr06_parens() {
        var result = testParse(EXPR, "(1+2)*3");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void lr07_nestedParens() {
        var result = testParse(EXPR, "((1+2))");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void lr08_direct() {
        var result = testParse(
            "S <- S \"x\" / \"y\" ;",
            "yxxx"
        );
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void lr09_multiDigit() {
        var result = testParse(LR1, "12+345+6789");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void lr10_complexExpr() {
        var result = testParse(EXPR, "1+2*3+4*5");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }
}
