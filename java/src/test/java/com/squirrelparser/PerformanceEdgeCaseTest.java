package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;
import java.util.stream.IntStream;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Optional;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Combinators.ZeroOrMore;
import com.squirrelparser.Terminals.Str;

/**
 * PERFORMANCE AND EDGE CASE TESTS (22 tests)
 * Port of performance_edge_case_test.dart
 *
 * These tests verify performance characteristics and edge cases.
 */
class PerformanceEdgeCaseTest {

    // ===========================================================================
    // PERFORMANCE TESTS
    // ===========================================================================

    @Test
    void testPERF_01_veryLongInput() {
        // 10,000 character input should parse in reasonable time
        var input = "x".repeat(10000);
        var start = System.currentTimeMillis();
        var r = parse(Map.of("S", new OneOrMore(new Str("x"))), input);
        var elapsed = System.currentTimeMillis() - start;

        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
        assertTrue(elapsed < 1000, "should complete in less than 1 second (was " + elapsed + "ms)");
    }

    @Test
    void testPERF_02_deepNesting() {
        // 50 levels of Seq nesting
        Clause clause = new Str("x");
        for (int i = 0; i < 50; i++) {
            clause = new Seq(clause, new Str("y"));
        }
        var grammar = Map.of("S", clause);
        var input = "x" + "y".repeat(50);

        var r = parse(grammar, input);
        assertTrue(r.success(), "should handle 50 levels of nesting");
    }

    @Test
    void testPERF_03_wideFirst() {
        // First with 50 alternatives (using padded numbers to avoid prefix issues)
        var alternatives = IntStream.range(0, 50)
            .mapToObj(i -> (Clause) new Str("opt_" + String.format("%03d", i)))
            .toArray(Clause[]::new);
        var r = parse(Map.of("S", new First(alternatives)), "opt_049"); // Last alternative
        assertTrue(r.success(), "should try all 50 alternatives");
    }

    @Test
    void testPERF_04_manyRepetitions() {
        // 1000 iterations of OneOrMore
        var input = "x".repeat(1000);
        var r = parse(Map.of("S", new OneOrMore(new Str("x"))), input);
        assertTrue(r.success(), "should handle 1000 repetitions");
    }

    @Test
    void testPERF_05_manyErrors() {
        // 500 errors in input
        var input = IntStream.range(0, 500).mapToObj(i -> "Xx").collect(java.util.stream.Collectors.joining());
        var r = parse(Map.of("S", new OneOrMore(new Str("x"))), input);
        assertTrue(r.success(), "should succeed");
        assertEquals(500, r.errorCount(), "should count all 500 errors");
    }

    @Test
    void testPERF_06_lrExpansionDepth() {
        // LR with 100 expansions
        var input = IntStream.range(0, 100).mapToObj(i -> "+n").collect(java.util.stream.Collectors.joining()).substring(1); // n+n+n+...
        var r = parse(Map.of(
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            )
        ), input, "E");
        assertTrue(r.success(), "should handle 100 LR expansions");
    }

    @Test
    void testPERF_07_cacheEfficiency() {
        // Same clause at many positions - cache should help
        var input = "x".repeat(100);
        var r = parse(Map.of("S", new OneOrMore(new Ref("X")), "X", new Str("x")), input);
        assertTrue(r.success(), "should succeed (cache makes this efficient)");
    }

    // ===========================================================================
    // EDGE CASE TESTS
    // ===========================================================================

    @Test
    void testEDGE_01_emptyInput() {
        // Various grammars with empty input
        var zm = parse(Map.of("S", new ZeroOrMore(new Str("x"))), "");
        assertTrue(zm.success(), "ZeroOrMore should succeed on empty");

        var om = parse(Map.of("S", new OneOrMore(new Str("x"))), "");
        assertFalse(om.success(), "OneOrMore should fail on empty");

        var opt = parse(Map.of("S", new Optional(new Str("x"))), "");
        assertTrue(opt.success(), "Optional should succeed on empty");

        var seq = parse(Map.of("S", new Seq()), "");
        assertTrue(seq.success(), "empty Seq should succeed on empty");
    }

    @Test
    void testEDGE_02_inputWithOnlyErrors() {
        // Input is all garbage
        var r = parse(Map.of("S", new Str("abc")), "XYZ");
        assertFalse(r.success(), "should fail (no valid content)");
    }

    @Test
    void testEDGE_03_grammarWithOnlyOptionalZeroOrMore() {
        // Grammar that accepts empty: Seq([ZeroOrMore(...), Optional(...)])
        var r = parse(Map.of(
            "S", new Seq(new ZeroOrMore(new Str("x")), new Optional(new Str("y")))
        ), "");
        assertTrue(r.success(), "should succeed (both match empty)");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testEDGE_04_singleCharTerminals() {
        // All single-character terminals
        var r = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("b"), new Str("c"))
        ), "abc");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testEDGE_05_veryLongTerminal() {
        // Multi-hundred-char terminal
        var longStr = "x".repeat(500);
        var r = parse(Map.of("S", new Str(longStr)), longStr);
        assertTrue(r.success(), "should match very long terminal");
    }

    @Test
    void testEDGE_06_unicodeHandling() {
        // Unicode characters in terminals and input
        var r = parse(Map.of(
            "S", new Seq(new Str("\u3053\u3093\u306b\u3061\u306f"), new Str("\u4e16\u754c"))
        ), "\u3053\u3093\u306b\u3061\u306f\u4e16\u754c");
        assertTrue(r.success(), "should handle Unicode");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testEDGE_07_mixedUnicodeAndAscii() {
        // Mix of Unicode and ASCII with errors
        var r = parse(Map.of(
            "S", new Seq(new Str("hello"), new Str("\u4e16\u754c"))
        ), "helloX\u4e16\u754c");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skipped().contains("X"), "should skip X");
    }

    @Test
    void testEDGE_08_newlinesAndWhitespace() {
        // Newlines and whitespace as errors
        var r = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("b"))
        ), "a\n\tb");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error (newline+tab)");
    }

    @Test
    void testEDGE_09_eofAtVariousPositions() {
        // EOF at different points in grammar
        var cases = new Object[][] {
            {"ab", 2},  // EOF after full match
            {"a", 1},   // EOF after partial match
            {"", 0}     // EOF at start
        };

        for (var testCase : cases) {
            String input = (String) testCase[0];
            var parser = new Parser(Map.of(
                "S", new Seq(new Str("a"), new Str("b"))
            ), input);
            var result = parser.parse("S");
            assertTrue(result != null || input.isEmpty(),
                "result should exist or input empty for \"" + input + "\"");
        }
    }

    @Test
    void testEDGE_10_recoveryWithModerateSkip() {
        // Recovery with moderate skip distance
        var r = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("b"), new Str("c"))
        ), "aXXXXXXXXXbc");
        assertTrue(r.success(), "should succeed (skip to find b)");
        assertEquals(1, r.errorCount(), "should have 1 error (skip region)");
        assertTrue(r.skipped().get(0).length() > 5, "should skip multiple chars");
    }

    @Test
    void testEDGE_11_alternatingSuccessFailure() {
        // Pattern that alternates between success and failure
        var r = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("a"), new Str("b")))
        ), "abXabYabZab");
        assertTrue(r.success(), "should succeed");
        assertEquals(3, r.errorCount(), "should have 3 errors");
    }

    @Test
    void testEDGE_12_boundaryAtEveryPosition() {
        // Multiple sequences with delimiters
        var r = parse(Map.of(
            "S", new Seq(
                new OneOrMore(new Str("a")),
                new Str(","),
                new OneOrMore(new Str("b")),
                new Str(","),
                new OneOrMore(new Str("c"))
            )
        ), "aaa,bbb,ccc");
        assertTrue(r.success(), "should succeed (multiple boundaries)");
    }

    @Test
    void testEDGE_13_noGrammarRules() {
        // Empty grammar (edge case that should fail gracefully)
        var parser = new Parser(Map.of(), "x");
        assertThrows(Exception.class, () -> parser.parse("NonExistent"),
            "should throw error for non-existent rule");
    }

    @Test
    void testEDGE_14_circularRefWithBaseCase() {
        // A -> A | 'x' (left-recursive with base case)
        // Should work correctly with LR detection
        var parser = new Parser(Map.of(
            "A", new First(
                new Seq(new Ref("A"), new Str("y")),
                new Str("x")
            )
        ), "xy");
        var result = parser.parse("A");
        // LR detection should handle this correctly
        assertTrue(result != null && !result.isMismatch(),
            "left-recursive with base case should work");
    }

    @Test
    void testEDGE_15_allPrintableAscii() {
        // Test all printable ASCII characters
        var ascii = IntStream.range(32, 127)
            .mapToObj(i -> String.valueOf((char) i))
            .collect(java.util.stream.Collectors.joining());
        var r = parse(Map.of("S", new Str(ascii)), ascii);
        assertTrue(r.success(), "should handle all printable ASCII");
    }
}
