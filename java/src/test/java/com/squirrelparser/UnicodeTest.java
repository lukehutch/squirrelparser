package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.Str;

/**
 * SECTION 10: UNICODE AND SPECIAL (10 tests)
 * Port of unicode_test.dart
 */
class UnicodeTest {

    @Test
    void testU01_Greek() {
        var result = parse(Map.of("S", new OneOrMore(new Str("α"))), "αβα");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("β"), "should skip β");
    }

    @Test
    void testU02_Chinese() {
        var result = parse(Map.of("S", new OneOrMore(new Str("中"))), "中文中");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("文"), "should skip 文");
    }

    @Test
    void testU03_ArabicClean() {
        var result = parse(Map.of("S", new OneOrMore(new Str("م"))), "ممم");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testU04_newline() {
        var result = parse(Map.of("S", new OneOrMore(new Str("x"))), "x\nx");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("\n"), "should skip newline");
    }

    @Test
    void testU05_tab() {
        var result = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("\t"), new Str("b"))
        ), "a\tb");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testU06_space() {
        var result = parse(Map.of("S", new OneOrMore(new Str("x"))), "x x");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains(" "), "should skip space");
    }

    @Test
    void testU07_multiSpace() {
        var result = parse(Map.of("S", new OneOrMore(new Str("x"))), "x   x");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("   "), "should skip spaces");
    }

    @Test
    void testU08_Japanese() {
        var result = parse(Map.of("S", new OneOrMore(new Str("日"))), "日本日");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("本"), "should skip 本");
    }

    @Test
    void testU09_Korean() {
        var result = parse(Map.of("S", new OneOrMore(new Str("한"))), "한글한");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("글"), "should skip 글");
    }

    @Test
    void testU10_mixedScripts() {
        var result = parse(Map.of(
            "S", new Seq(new Str("α"), new Str("中"), new Str("!"))
        ), "α中!");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }
}
