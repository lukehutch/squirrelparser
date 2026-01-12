// ===========================================================================
// BOUND PROPAGATION TESTS (FIX #9 Verification)
// ===========================================================================
// These tests verify that bounds propagate through arbitrary nesting levels
// to correctly stop repetitions before consuming delimiters.

package com.squirrelparser;

import static com.squirrelparser.TestUtils.testParse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class BoundPropagationTest {

    @Test
    void bp01_directRepetition() {
        // Baseline: Bound with direct Repetition child (was already working)
        var result = testParse("S <- \"x\"+ \"end\" ;", "xxxxend");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void bp02_throughRef() {
        // FIX #9: Bound propagates through Ref
        String grammar = """
            S <- A "end" ;
            A <- "x"+ ;
            """;
        var result = testParse(grammar, "xxxxend");
        assertTrue(result.ok(), "should succeed (bound through Ref)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void bp03_throughNestedRefs() {
        // FIX #9: Bound propagates through multiple Refs
        String grammar = """
            S <- A "end" ;
            A <- B ;
            B <- "x"+ ;
            """;
        var result = testParse(grammar, "xxxxend");
        assertTrue(result.ok(), "should succeed (bound through 2 Refs)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void bp04_throughFirst() {
        // FIX #9: Bound propagates through First alternatives
        String grammar = """
            S <- A "end" ;
            A <- "x"+ / "y"+ ;
            """;
        var result = testParse(grammar, "xxxxend");
        assertTrue(result.ok(), "should succeed (bound through First)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void bp05_leftRecursiveWithRepetition() {
        // FIX #9: The EMERG-01 case - bound through LR + First + Seq + Repetition
        String grammar = """
            S <- E "end" ;
            E <- E "+" "n"+ / "n" ;
            """;
        var result = testParse(grammar, "n+nnn+nnend");
        assertTrue(result.ok(), "should succeed (bound through LR)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void bp06_withRecoveryInsideBoundedRep() {
        // FIX #9 + recovery: Bound propagates AND recovery works inside repetition
        String grammar = """
            S <- A "end" ;
            A <- "ab"+ ;
            """;
        var result = testParse(grammar, "abXabYabend");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors (X and Y)");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        assertTrue(result.skippedStrings().contains("Y"), "should skip Y");
    }

    @Test
    void bp07_multipleBoundsNestedSeq() {
        // Multiple bounds in nested Seq structures
        String grammar = """
            S <- A ";" B "end" ;
            A <- "x"+ ;
            B <- "y"+ ;
            """;
        var result = testParse(grammar, "xxxx;yyyyend");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // A stops at ';', B stops at 'end'
    }

    @Test
    void bp08_boundVsEof() {
        // Without explicit bound, should consume until EOF
        var result = testParse("S <- \"x\"+ ;", "xxxx");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // No bound, so consumes all x's
    }

    @Test
    void bp09_zeroormoreWithBound() {
        // Bound applies to ZeroOrMore too
        var result = testParse("S <- \"x\"* \"end\" ;", "end");
        assertTrue(result.ok(), "should succeed (ZeroOrMore matches 0)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void bp10_complexNesting() {
        // Deeply nested: Ref -> First -> Seq -> Ref -> Repetition
        String grammar = """
            S <- A "end" ;
            A <- "a" B / "fallback" ;
            B <- "x"+ ;
            """;
        var result = testParse(grammar, "axxxxend");
        assertTrue(result.ok(), "should succeed (bound through complex nesting)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }
}
