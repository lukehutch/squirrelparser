package com.squirrelparser;

import static com.squirrelparser.TestUtils.countDeletions;
import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.Str;

/**
 * VISIBILITY CONSTRAINT TESTS (FIX #8 Verification) (10 tests)
 * Port of visibility_constraint_test.dart
 *
 * These tests verify that parse trees match visible input structure and that
 * grammar deletion (inserting missing elements) only occurs at EOF.
 */
class VisibilityConstraintTest {

    @Test
    void testVIS01TerminalAtomicity() {
        var parser = new Parser(
            Map.of("S", new Seq(new Str("abc"), new Str("def"))),
            "abXdef"
        );
        var result = parser.parse("S");
        // Total failure returns SyntaxError or partial match with trailing SyntaxError
        assertTrue(result instanceof SyntaxError,
            "should fail (cannot skip within multi-char terminal)");
    }

    @Test
    void testVIS02GrammarDeletionAtEOF() {
        var r = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("b"), new Str("c"))
        ), "ab");
        assertTrue(r.success(), "should succeed (delete c at EOF)");
        var parser = new Parser(
            Map.of("S", new Seq(new Str("a"), new Str("b"), new Str("c"))),
            "ab"
        );
        assertEquals(1, countDeletions(parser.parse("S")), "should have 1 deletion");
    }

    @Test
    void testVIS03GrammarDeletionMidParseForbidden() {
        var parser = new Parser(
            Map.of("S", new Seq(new Str("a"), new Str("b"), new Str("c"))),
            "ac"
        );
        var result = parser.parse("S");
        // Total failure returns SyntaxError or partial match with trailing SyntaxError
        assertTrue(result instanceof SyntaxError,
            "should fail (mid-parse grammar deletion violates Visibility Constraint)");
    }

    @Test
    void testVIS04TreeStructureMatchesVisibleInput() {
        var r = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("b"), new Str("c"))
        ), "aXbc");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skipped().contains("X"), "should skip X");
    }

    @Test
    void testVIS05HiddenDeletionCreatesMismatch() {
        var parser = new Parser(
            Map.of(
                "S", new First(
                    new Seq(new Str("a"), new Str("b")),
                    new Str("c")
                )
            ),
            "a"
        );
        var result = parser.parse("S");
        assertTrue(result != null && !result.isMismatch(),
            "should succeed (first alternative with EOF deletion)");
        assertEquals(1, result.len(), "should consume 1 char (a)");
    }

    @Test
    void testVIS06MultipleConsecutiveSkips() {
        var r = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("b"), new Str("c"))
        ), "aXXXXbc");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error (entire XXXX region)");
        assertTrue(r.skipped().contains("XXXX"), "should skip XXXX as one region");
    }

    @Test
    void testVIS07AlternatingContentAndErrors() {
        var r = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("b"), new Str("c"), new Str("d"))
        ), "aXbYcZd");
        assertTrue(r.success(), "should succeed");
        assertEquals(3, r.errorCount(), "should have 3 errors");
        assertTrue(r.skipped().contains("X"), "should skip X");
        assertTrue(r.skipped().contains("Y"), "should skip Y");
        assertTrue(r.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testVIS08CompletionVsCorrection() {
        var comp = parse(Map.of(
            "S", new Seq(new Str("if"), new Str("("), new Str("x"), new Str(")"))
        ), "if(x");
        assertTrue(comp.success(), "completion should succeed");

        var corr = new Parser(
            Map.of("S", new Seq(new Str("if"), new Str("("), new Str("x"), new Str(")"))),
            "if()"
        );
        var result = corr.parse("S");
        // Total failure returns SyntaxError or partial match with trailing SyntaxError
        assertTrue(result instanceof SyntaxError,
            "mid-parse correction should fail");
    }

    @Test
    void testVIS09StructuralIntegrity() {
        var r = parse(Map.of(
            "S", new Seq(new Str("("), new Str("E"), new Str(")"))
        ), "E)");
        assertFalse(r.success(), "should fail (cannot reorganize visible structure)");
    }

    @Test
    void testVIS10VisibilityWithNestedStructures() {
        var r = parse(Map.of(
            "S", new Seq(
                new Seq(new Str("a"), new Str("b")),
                new Str("c")
            )
        ), "aXbc");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skipped().contains("X"), "should skip X in inner Seq");
    }
}
