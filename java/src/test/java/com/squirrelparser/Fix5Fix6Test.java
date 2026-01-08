package com.squirrelparser;

import static com.squirrelparser.TestUtils.countDeletions;
import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Optional;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.Str;

/**
 * SECTION 5: FIX #5/#6 - OPTIONAL AND EOF (14 tests)
 * Port of fix5_fix6_test.dart
 */
class Fix5Fix6Test {

    // Mutual recursion grammar
    private static final Map<String, Clause> mr = Map.of(
        "S", new Ref("A"),
        "A", new First(
            new Seq(new Str("a"), new Ref("B")),
            new Str("y")
        ),
        "B", new First(
            new Seq(new Str("b"), new Ref("A")),
            new Str("x")
        )
    );

    @Test
    void testF5_01_Aby() {
        var result = parse(mr, "aby");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testF5_02_AbZy() {
        var result = parse(mr, "abZy");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF5_03_Ababy() {
        var result = parse(mr, "ababy");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testF5_04_Ax() {
        var result = parse(mr, "ax");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testF5_05_Y() {
        var result = parse(mr, "y");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testF5_06_Abx() {
        // 'abx' is NOT in the language
        var result = parse(mr, "abx");
        assertTrue(result.success(), "should succeed with recovery");
        assertTrue(result.errorCount() >= 1, "should have at least 1 error");
    }

    @Test
    void testF5_06b_Abax() {
        // 'abax' IS in the language
        var result = parse(mr, "abax");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testF5_07_Ababx() {
        // 'ababx' is NOT in the language
        var result = parse(mr, "ababx");
        assertTrue(result.success(), "should succeed with recovery");
        assertTrue(result.errorCount() >= 1, "should have at least 1 error");
    }

    @Test
    void testF5_07b_Ababax() {
        // 'ababax' IS in the language
        var result = parse(mr, "ababax");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testF6_01_OptionalWrapper() {
        var result = parse(Map.of(
            "S", new Optional(new Seq(new OneOrMore(new Str("x")), new Str("!")))
        ), "xZx!");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF6_02_OptionalAtEOF() {
        var result = parse(Map.of(
            "S", new Optional(new Str("x"))
        ), "");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testF6_03_NestedOptional() {
        var result = parse(Map.of(
            "S", new Optional(new Optional(new Seq(new OneOrMore(new Str("x")), new Str("!"))))
        ), "xZx!");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF6_04_OptionalInSeq() {
        var result = parse(Map.of(
            "S", new Seq(
                new Optional(new Seq(new OneOrMore(new Str("x")))),
                new Str("!")
            )
        ), "xZx!");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testF6_05_EOFDelOk() {
        Parser parser = new Parser(Map.of(
            "S", new Seq(new Str("a"), new Str("b"), new Str("c"))
        ), "ab");
        MatchResult result = parser.parse("S");
        assertNotNull(result);
        assertFalse(result.isMismatch(), "should succeed with recovery");
        assertEquals(1, countDeletions(result), "should have 1 deletion");
    }
}
