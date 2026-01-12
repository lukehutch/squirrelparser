package com.squirrelparser;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import static com.squirrelparser.TestUtils.*;
import static org.junit.jupiter.api.Assertions.*;

/**
 * PERFORMANCE & EDGE CASE TESTS
 *
 * These tests verify performance characteristics and edge cases.
 */
class PerformanceEdgeCaseTest {

    @Nested
    class PerformanceTests {
        @Test
        void testPERF01_VeryLongInput() {
            // 10,000 character input should parse in reasonable time
            String input = "x".repeat(10000);
            long startTime = System.currentTimeMillis();
            ParseTestResult r = testParse("S <- \"x\"+ ;", input);
            long elapsed = System.currentTimeMillis() - startTime;

            assertTrue(r.ok(), "should succeed");
            assertEquals(0, r.errorCount(), "should have 0 errors");
            assertTrue(elapsed < 1000, "should complete in less than 1 second (was " + elapsed + "ms)");
        }

        @Test
        void testPERF02_DeepNesting() {
            // 50 levels of Seq nesting
            String inner = "\"x\"";
            for (int i = 0; i < 50; i++) {
                inner = "(" + inner + " \"y\")";
            }
            String grammarSpec = "S <- " + inner + " ;";
            String input = "x" + "y".repeat(50);

            ParseTestResult r = testParse(grammarSpec, input);
            assertTrue(r.ok(), "should handle 50 levels of nesting");
        }

        @Test
        void testPERF03_WideFirst() {
            // First with 50 alternatives (using padded numbers to avoid prefix issues)
            String alternatives = IntStream.range(0, 50)
                .mapToObj(i -> String.format("\"opt_%03d\"", i))
                .collect(Collectors.joining(" / "));
            String grammarSpec = "S <- " + alternatives + " ;";

            ParseTestResult r = testParse(grammarSpec, "opt_049");
            assertTrue(r.ok(), "should try all 50 alternatives");
        }

        @Test
        void testPERF04_ManyRepetitions() {
            // 1000 iterations of OneOrMore
            String input = "x".repeat(1000);
            ParseTestResult r = testParse("S <- \"x\"+ ;", input);
            assertTrue(r.ok(), "should handle 1000 repetitions");
        }

        @Test
        void testPERF05_ManyErrors() {
            // 500 errors in input
            String input = IntStream.range(0, 500)
                .mapToObj(i -> "Xx")
                .collect(Collectors.joining());
            ParseTestResult r = testParse("S <- \"x\"+ ;", input);
            assertTrue(r.ok(), "should succeed");
            assertEquals(500, r.errorCount(), "should count all 500 errors");
        }

        @Test
        void testPERF06_LRExpansionDepth() {
            // LR with 100 expansions
            String input = IntStream.range(0, 100)
                .mapToObj(i -> "+n")
                .collect(Collectors.joining())
                .substring(1);  // n+n+n+...
            ParseTestResult r = testParse(
                "E <- E \"+\" \"n\" / \"n\" ;",
                input,
                "E"
            );
            assertTrue(r.ok(), "should handle 100 LR expansions");
        }

        @Test
        void testPERF07_CacheEfficiency() {
            // Same clause at many positions - cache should help
            String input = "x".repeat(100);
            String grammar = """
                S <- X+ ;
                X <- "x" ;
                """;
            ParseTestResult r = testParse(grammar, input);
            assertTrue(r.ok(), "should succeed (cache makes this efficient)");
        }
    }

    @Nested
    class EdgeCaseTests {
        @Test
        void testEDGE01_EmptyInput() {
            // Various grammars with empty input
            ParseTestResult zm = testParse("S <- \"x\"* ;", "");
            assertTrue(zm.ok(), "ZeroOrMore should succeed on empty");

            ParseTestResult om = testParse("S <- \"x\"+ ;", "");
            assertFalse(om.ok(), "OneOrMore should fail on empty");

            ParseTestResult opt = testParse("S <- \"x\"? ;", "");
            assertTrue(opt.ok(), "Optional should succeed on empty");

            // Empty sequence (no elements) matches empty input
            ParseResult parseResult = SquirrelParser.squirrelParsePT(
                "S <- \"\"? ;",  // Optional empty string
                "S",
                ""
            );
            assertTrue(!parseResult.root().isMismatch(), "empty pattern should succeed on empty");
        }

        @Test
        void testEDGE02_InputWithOnlyErrors() {
            // Input is all garbage
            ParseTestResult r = testParse("S <- \"abc\" ;", "XYZ");
            assertFalse(r.ok(), "should fail (no valid content)");
        }

        @Test
        void testEDGE03_GrammarWithOnlyOptionalZeroOrMore() {
            // Grammar that accepts empty: Seq([ZeroOrMore(...), Optional(...)])
            ParseTestResult r = testParse("S <- \"x\"* \"y\"? ;", "");
            assertTrue(r.ok(), "should succeed (both match empty)");
            assertEquals(0, r.errorCount(), "should have 0 errors");
        }

        @Test
        void testEDGE04_SingleCharTerminals() {
            // All single-character terminals
            ParseTestResult r = testParse("S <- \"a\" \"b\" \"c\" ;", "abc");
            assertTrue(r.ok(), "should succeed");
            assertEquals(0, r.errorCount(), "should have 0 errors");
        }

        @Test
        void testEDGE05_VeryLongTerminal() {
            // Multi-hundred-char terminal
            String longStr = "x".repeat(500);
            ParseTestResult r = testParse("S <- \"" + longStr + "\" ;", longStr);
            assertTrue(r.ok(), "should match very long terminal");
        }

        @Test
        void testEDGE06_UnicodeHandling() {
            // Unicode characters in terminals and input
            ParseTestResult r = testParse(
                "S <- \"\u3053\u3093\u306b\u3061\u306f\" \"\u4e16\u754c\" ;",
                "\u3053\u3093\u306b\u3061\u306f\u4e16\u754c"  // "Hello" "World" in Japanese
            );
            assertTrue(r.ok(), "should handle Unicode");
            assertEquals(0, r.errorCount(), "should have 0 errors");
        }

        @Test
        void testEDGE07_MixedUnicodeAndAscii() {
            // Mix of Unicode and ASCII with errors
            ParseTestResult r = testParse(
                "S <- \"hello\" \"\u4e16\u754c\" ;",
                "helloX\u4e16\u754c"
            );
            assertTrue(r.ok(), "should succeed");
            assertEquals(1, r.errorCount(), "should have 1 error");
            assertTrue(r.skippedStrings().contains("X"), "should skip X");
        }

        @Test
        void testEDGE08_NewlinesAndWhitespace() {
            // Newlines and whitespace as errors
            ParseTestResult r = testParse("S <- \"a\" \"b\" ;", "a\n\tb");
            assertTrue(r.ok(), "should succeed");
            assertEquals(1, r.errorCount(), "should have 1 error (newline+tab)");
        }

        @Test
        void testEDGE09_EOFAtVariousPositions() {
            // EOF at different points in grammar
            String[][] cases = {
                {"ab", "2"},  // EOF after full match
                {"a", "1"},   // EOF after partial match
                {"", "0"},    // EOF at start
            };

            for (String[] testCase : cases) {
                String input = testCase[0];
                ParseResult parseResult = SquirrelParser.squirrelParsePT(
                    "S <- \"a\" \"b\" ;",
                    "S",
                    input
                );
                MatchResult result = parseResult.root();
                assertTrue(!(result instanceof SyntaxError) || input.isEmpty(),
                    "result should exist or input empty for \"" + input + "\"");
            }
        }

        @Test
        void testEDGE10_RecoveryWithModerateSkip() {
            // Recovery with moderate skip distance
            ParseTestResult r = testParse(
                "S <- \"a\" \"b\" \"c\" ;",
                "aXXXXXXXXXbc"
            );
            assertTrue(r.ok(), "should succeed (skip to find b)");
            assertEquals(1, r.errorCount(), "should have 1 error (skip region)");
            assertTrue(r.skippedStrings().get(0).length() > 5, "should skip multiple chars");
        }

        @Test
        void testEDGE11_AlternatingSuccessFailure() {
            // Pattern that alternates between success and failure
            ParseTestResult r = testParse(
                "S <- (\"a\" \"b\")+ ;",
                "abXabYabZab"
            );
            assertTrue(r.ok(), "should succeed");
            assertEquals(3, r.errorCount(), "should have 3 errors");
        }

        @Test
        void testEDGE12_BoundaryAtEveryPosition() {
            // Multiple sequences with delimiters
            ParseTestResult r = testParse(
                "S <- \"a\"+ \",\" \"b\"+ \",\" \"c\"+ ;",
                "aaa,bbb,ccc"
            );
            assertTrue(r.ok(), "should succeed (multiple boundaries)");
        }

        @Test
        void testEDGE13_NoGrammarRules() {
            // Empty grammar (edge case that should fail gracefully)
            assertThrows(IllegalArgumentException.class, () -> {
                new Parser(Map.of(), "S", "x").parse();
            }, "should throw error for non-existent rule");
        }

        @Test
        void testEDGE14_CircularRefWithBaseCase() {
            // A -> A | 'x' (left-recursive with base case)
            // Should work correctly with LR detection
            ParseResult parseResult = SquirrelParser.squirrelParsePT(
                "A <- A \"y\" / \"x\" ;",
                "A",
                "xy"
            );
            MatchResult result = parseResult.root();
            assertTrue(!result.isMismatch(), "left-recursive with base case should work");
        }

        @Test
        void testEDGE15_AllPrintableASCII() {
            // Test all printable ASCII characters
            String ascii = IntStream.range(32, 127)
                .mapToObj(i -> String.valueOf((char) i))
                .collect(Collectors.joining());

            // Escape special characters for the grammar spec string literal
            String escaped = ascii
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t");

            ParseTestResult r = testParse("S <- \"" + escaped + "\" ;", ascii);
            assertTrue(r.ok(), "should handle all printable ASCII");
        }
    }
}
