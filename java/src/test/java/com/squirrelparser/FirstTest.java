package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.Str;

/**
 * SECTION 8: FIRST (ORDERED CHOICE) (15 tests)
 * Port of first_test.dart
 */
class FirstTest {

    @Test
    void testFR01_match1st() {
        var result = parse(Map.of(
            "S", new First(new Str("abc"), new Str("ab"), new Str("a"))
        ), "abc");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testFR02_match2nd() {
        var result = parse(Map.of(
            "S", new First(new Str("xyz"), new Str("abc"))
        ), "abc");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testFR03_match3rd() {
        var result = parse(Map.of(
            "S", new First(new Str("x"), new Str("y"), new Str("z"))
        ), "z");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testFR04_withRecovery() {
        var result = parse(Map.of(
            "S", new First(
                new Seq(new OneOrMore(new Str("x")), new Str("!")),
                new Str("fallback")
            )
        ), "xZx!");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testFR05_fallback() {
        var result = parse(Map.of(
            "S", new First(
                new Seq(new Str("a"), new Str("b")),
                new Str("x")
            )
        ), "x");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testFR06_noneMatch() {
        var result = parse(Map.of(
            "S", new First(new Str("a"), new Str("b"), new Str("c"))
        ), "x");
        assertFalse(result.success(), "should fail");
    }

    @Test
    void testFR07_nested() {
        var result = parse(Map.of(
            "S", new First(
                new First(new Str("a"), new Str("b")),
                new Str("c")
            )
        ), "b");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testFR08_deepNested() {
        var result = parse(Map.of(
            "S", new First(
                new First(
                    new First(new Str("a"))
                )
            )
        ), "a");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }
}
