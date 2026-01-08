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
import com.squirrelparser.Combinators.ZeroOrMore;
import com.squirrelparser.Terminals.Str;

/**
 * BOUND PROPAGATION TESTS (FIX #9 Verification)
 * Port of bound_propagation_test.dart
 *
 * These tests verify that bounds propagate through arbitrary nesting levels
 * to correctly stop repetitions before consuming delimiters.
 */
class BoundPropagationTest {

    @Test
    void testBP01_directRepetition() {
        // Baseline: Bound with direct Repetition child (was already working)
        var r = parse(Map.of(
            "S", new Seq(new OneOrMore(new Str("x")), new Str("end"))
        ), "xxxxend");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testBP02_throughRef() {
        // FIX #9: Bound propagates through Ref
        var r = parse(Map.of(
            "S", new Seq(new Ref("A"), new Str("end")),
            "A", new OneOrMore(new Str("x"))
        ), "xxxxend");
        assertTrue(r.success(), "should succeed (bound through Ref)");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testBP03_throughNestedRefs() {
        // FIX #9: Bound propagates through multiple Refs
        var r = parse(Map.of(
            "S", new Seq(new Ref("A"), new Str("end")),
            "A", new Ref("B"),
            "B", new OneOrMore(new Str("x"))
        ), "xxxxend");
        assertTrue(r.success(), "should succeed (bound through 2 Refs)");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testBP04_throughFirst() {
        // FIX #9: Bound propagates through First alternatives
        var r = parse(Map.of(
            "S", new Seq(new Ref("A"), new Str("end")),
            "A", new First(new OneOrMore(new Str("x")), new OneOrMore(new Str("y")))
        ), "xxxxend");
        assertTrue(r.success(), "should succeed (bound through First)");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testBP05_leftRecursiveWithRepetition() {
        // FIX #9: The EMERG-01 case - bound through LR + First + Seq + Repetition
        var r = parse(Map.of(
            "S", new Seq(new Ref("E"), new Str("end")),
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new OneOrMore(new Str("n"))),
                new Str("n")
            )
        ), "n+nnn+nnend");
        assertTrue(r.success(), "should succeed (bound through LR)");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testBP06_withRecoveryInsideBoundedRep() {
        // FIX #9 + recovery: Bound propagates AND recovery works inside repetition
        var r = parse(Map.of(
            "S", new Seq(new Ref("A"), new Str("end")),
            "A", new OneOrMore(new Str("ab"))
        ), "abXabYabend");
        assertTrue(r.success(), "should succeed");
        assertEquals(2, r.errorCount(), "should have 2 errors (X and Y)");
        assertTrue(r.skipped().contains("X"), "should skip X");
        assertTrue(r.skipped().contains("Y"), "should skip Y");
    }

    @Test
    void testBP07_multipleBoundsNestedSeq() {
        // Multiple bounds in nested Seq structures
        var r = parse(Map.of(
            "S", new Seq(new Ref("A"), new Str(";"), new Ref("B"), new Str("end")),
            "A", new OneOrMore(new Str("x")),
            "B", new OneOrMore(new Str("y"))
        ), "xxxx;yyyyend");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
        // A stops at ';', B stops at 'end'
    }

    @Test
    void testBP08_boundVsEOF() {
        // Without explicit bound, should consume until EOF
        var r = parse(Map.of("S", new OneOrMore(new Str("x"))), "xxxx");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
        // No bound, so consumes all x's
    }

    @Test
    void testBP09_zeroOrMoreWithBound() {
        // Bound applies to ZeroOrMore too
        var r = parse(Map.of(
            "S", new Seq(new ZeroOrMore(new Str("x")), new Str("end"))
        ), "end");
        assertTrue(r.success(), "should succeed (ZeroOrMore matches 0)");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testBP10_complexNesting() {
        // Deeply nested: Ref -> First -> Seq -> Ref -> Repetition
        var r = parse(Map.of(
            "S", new Seq(new Ref("A"), new Str("end")),
            "A", new First(
                new Seq(new Str("a"), new Ref("B")),
                new Str("fallback")
            ),
            "B", new OneOrMore(new Str("x"))
        ), "axxxxend");
        assertTrue(r.success(), "should succeed (bound through complex nesting)");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }
}
