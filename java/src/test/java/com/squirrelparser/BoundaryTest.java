package com.squirrelparser;

import static com.squirrelparser.TestUtils.countDeletions;
import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Optional;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Combinators.ZeroOrMore;
import com.squirrelparser.Terminals.AnyChar;
import com.squirrelparser.Terminals.CharRange;
import com.squirrelparser.Terminals.Str;

/**
 * SECTION 1: EMPTY AND BOUNDARY CONDITIONS (27 tests)
 * Port of boundary_test.dart
 */
class BoundaryTest {

    @Test
    void testE01_ZeroOrMoreEmpty() {
        var result = parse(Map.of("S", new ZeroOrMore(new Str("x"))), "");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE02_OneOrMoreEmpty() {
        var result = parse(Map.of("S", new OneOrMore(new Str("x"))), "");
        assertFalse(result.success(), "should fail");
    }

    @Test
    void testE03_OptionalEmpty() {
        var result = parse(Map.of("S", new Optional(new Str("x"))), "");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE04_SeqEmptyRecovery() {
        var parser = new Parser(Map.of(
            "S", new Seq(new Str("a"), new Str("b"))
        ), "");
        var matchResult = parser.parse("S");
        assertTrue(matchResult != null && !matchResult.isMismatch(),
            "should succeed with recovery");
        assertEquals(2, countDeletions(matchResult),
            "should have 2 deletions");
    }

    @Test
    void testE05_FirstEmpty() {
        var result = parse(Map.of(
            "S", new First(new Str("a"), new Str("b"))
        ), "");
        assertFalse(result.success(), "should fail");
    }

    @Test
    void testE06_RefEmpty() {
        var result = parse(Map.of("S", new Ref("A"), "A", new Str("x")), "");
        assertFalse(result.success(), "should fail");
    }

    @Test
    void testE07_SingleCharMatch() {
        var result = parse(Map.of("S", new Str("x")), "x");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE08_SingleCharMismatch() {
        var result = parse(Map.of("S", new Str("x")), "y");
        assertFalse(result.success(), "should fail");
    }

    @Test
    void testE09_ZeroOrMoreSingle() {
        var result = parse(Map.of("S", new ZeroOrMore(new Str("x"))), "x");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE10_OneOrMoreSingle() {
        var result = parse(Map.of("S", new OneOrMore(new Str("x"))), "x");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE11_OptionalMatch() {
        var result = parse(Map.of("S", new Optional(new Str("x"))), "x");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE12_TwoCharsMatch() {
        var result = parse(Map.of("S", new Str("xy")), "xy");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE13_TwoCharsPartial() {
        var result = parse(Map.of("S", new Str("xy")), "x");
        assertFalse(result.success(), "should fail");
    }

    @Test
    void testE14_CharRangeMatch() {
        var result = parse(Map.of("S", new CharRange("a", "z")), "m");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE15_CharRangeBoundaryLow() {
        var result = parse(Map.of("S", new CharRange("a", "z")), "a");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE16_CharRangeBoundaryHigh() {
        var result = parse(Map.of("S", new CharRange("a", "z")), "z");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE17_CharRangeFailLow() {
        var result = parse(Map.of("S", new CharRange("b", "y")), "a");
        assertFalse(result.success(), "should fail");
    }

    @Test
    void testE18_CharRangeFailHigh() {
        var result = parse(Map.of("S", new CharRange("b", "y")), "z");
        assertFalse(result.success(), "should fail");
    }

    @Test
    void testE19_AnyCharMatch() {
        var result = parse(Map.of("S", new AnyChar()), "x");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE20_AnyCharEmpty() {
        var result = parse(Map.of("S", new AnyChar()), "");
        assertFalse(result.success(), "should fail");
    }

    @Test
    void testE21_SeqSingle() {
        var result = parse(Map.of(
            "S", new Seq(new Str("x"))
        ), "x");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE22_FirstSingle() {
        var result = parse(Map.of(
            "S", new First(new Str("x"))
        ), "x");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE23_NestedEmpty() {
        var result = parse(Map.of(
            "S", new Seq(new Optional(new Str("a")), new Optional(new Str("b")))
        ), "");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE24_ZeroOrMoreMulti() {
        var result = parse(Map.of("S", new ZeroOrMore(new Str("x"))), "xxx");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE25_OneOrMoreMulti() {
        var result = parse(Map.of("S", new OneOrMore(new Str("x"))), "xxx");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE26_LongStringMatch() {
        var result = parse(Map.of("S", new Str("abcdefghij")), "abcdefghij");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testE27_LongStringPartial() {
        var result = parse(Map.of("S", new Str("abcdefghij")), "abcdefghi");
        assertFalse(result.success(), "should fail");
    }
}
