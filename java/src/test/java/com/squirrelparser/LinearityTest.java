package com.squirrelparser;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.stream.Collectors;
import java.util.stream.IntStream;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

/**
 * SECTION 12: LINEARITY TESTS (10 tests)
 *
 * Verify O(N) complexity where N is input length.
 * Work should scale linearly with input size.
 */
class LinearityTest {

    @BeforeAll
    static void setUpAll() {
        // Enable stats tracking for linearity tests
        ParserStats.enable();
    }

    @AfterAll
    static void tearDownAll() {
        // Disable stats tracking after linearity tests
        ParserStats.disable();
    }

    /**
     * Result of linearity test: (passed, ratioChange).
     * ratioChange < 2 means linear.
     */
    record LinearityResult(boolean passed, double ratioChange) {}

    /**
     * Test linearity helper.
     */
    LinearityResult testLinearity(
            String grammarSpec,
            String topRule,
            java.util.function.IntFunction<String> makeInput,
            int[] sizes) {

        record SizeResult(int size, int work, double ratio) {}
        var results = new java.util.ArrayList<SizeResult>();

        for (int size : sizes) {
            ParserStats.get().reset();
            String input = makeInput.apply(size);
            ParseResult parseResult = SquirrelParser.squirrelParsePT(grammarSpec, topRule, input);
            MatchResult result = parseResult.root();

            int work = ParserStats.get().totalWork();
            boolean success = !result.isMismatch() && result.len() == input.length();
            double ratio = size > 0 ? (double) work / size : 0.0;

            results.add(new SizeResult(size, work, ratio));

            if (!success) {
                return new LinearityResult(false, Double.POSITIVE_INFINITY);
            }
        }

        // Check ratio doesn't increase significantly
        var ratios = results.stream().map(SizeResult::ratio).toList();
        if (ratios.isEmpty() || ratios.getFirst() == 0) {
            return new LinearityResult(false, Double.POSITIVE_INFINITY);
        }

        double ratioChange = ratios.getLast() / ratios.getFirst();
        return new LinearityResult(ratioChange <= 2.0, ratioChange);
    }

    @Test
    void testLinear01SimpleRep() {
        LinearityResult result = testLinearity(
            "S <- \"x\"+ ;",
            "S",
            size -> "x".repeat(size),
            new int[]{10, 50, 100, 500}
        );
        assertTrue(result.passed(), "simple repetition should be linear (ratio change: " + result.ratioChange() + ")");
    }

    @Test
    void testLinear02DirectLR() {
        String grammar = """
            E <- E "+" N / N ;
            N <- [0-9] ;
            """;
        LinearityResult result = testLinearity(
            grammar,
            "E",
            size -> IntStream.range(0, size + 1)
                .mapToObj(i -> String.valueOf(i % 10))
                .collect(Collectors.joining("+")),
            new int[]{5, 10, 20, 50}
        );
        assertTrue(result.passed(), "direct LR should be linear (ratio change: " + result.ratioChange() + ")");
    }

    @Test
    void testLinear03IndirectLR() {
        String grammar = """
            A <- B / "x" ;
            B <- A "y" / A "x" ;
            """;
        LinearityResult result = testLinearity(
            grammar,
            "A",
            size -> {
                StringBuilder s = new StringBuilder("x");
                for (int i = 0; i < size / 2; i++) {
                    s.append("xy");
                }
                return s.substring(0, Math.max(1, size));
            },
            new int[]{5, 10, 20, 50}
        );
        assertTrue(result.passed(), "indirect LR should be linear (ratio change: " + result.ratioChange() + ")");
    }

    @Test
    void testLinear04InterwovenLR() {
        String grammar = """
            L <- P ".x" / "x" ;
            P <- P "(n)" / L ;
            """;
        LinearityResult result = testLinearity(
            grammar,
            "L",
            size -> {
                StringBuilder parts = new StringBuilder("x");
                for (int i = 0; i < size; i++) {
                    parts.append(i % 3 == 0 ? ".x" : "(n)");
                }
                return parts.toString();
            },
            new int[]{5, 10, 20, 50}
        );
        assertTrue(result.passed(), "interwoven LR should be linear (ratio change: " + result.ratioChange() + ")");
    }

    @Test
    void testLinear05DeepNesting() {
        String grammar = """
            E <- "(" E ")" / "x" ;
            """;
        LinearityResult result = testLinearity(
            grammar,
            "E",
            size -> "(".repeat(size) + "x" + ")".repeat(size),
            new int[]{5, 10, 20, 50}
        );
        assertTrue(result.passed(), "deep nesting should be linear (ratio change: " + result.ratioChange() + ")");
    }

    @Test
    void testLinear06Precedence() {
        String grammar = """
            E <- E "+" T / T ;
            T <- T "*" F / F ;
            F <- "(" E ")" / N ;
            N <- [0-9] ;
            """;
        LinearityResult result = testLinearity(
            grammar,
            "E",
            size -> {
                StringBuilder parts = new StringBuilder();
                for (int i = 0; i < size; i++) {
                    parts.append(i % 10);
                    if (i < size - 1) {
                        parts.append(i % 2 == 0 ? "+" : "*");
                    }
                }
                return parts.toString();
            },
            new int[]{5, 10, 20, 50}
        );
        assertTrue(result.passed(), "precedence grammar should be linear (ratio change: " + result.ratioChange() + ")");
    }

    @Test
    void testLinear07Ambiguous() {
        String grammar = """
            E <- E "+" E / N ;
            N <- [0-9] ;
            """;
        LinearityResult result = testLinearity(
            grammar,
            "E",
            size -> IntStream.range(0, size + 1)
                .mapToObj(i -> String.valueOf(i % 10))
                .collect(Collectors.joining("+")),
            new int[]{3, 5, 7, 10}  // Smaller sizes for ambiguous grammar
        );
        assertTrue(result.passed(), "ambiguous grammar should be linear (ratio change: " + result.ratioChange() + ")");
    }

    @Test
    void testLinear08LongInput() {
        String grammar = """
            S <- ("a" "b" "c")+ ;
            """;
        LinearityResult result = testLinearity(
            grammar,
            "S",
            size -> "abc".repeat(size),
            new int[]{100, 500, 1000, 2000}
        );
        assertTrue(result.passed(), "long input should be linear (ratio change: " + result.ratioChange() + ")");
    }

    @Test
    void testLinear09LongLR() {
        String grammar = """
            E <- E "+" N / N ;
            N <- [0-9] ;
            """;
        LinearityResult result = testLinearity(
            grammar,
            "E",
            size -> IntStream.range(0, size)
                .mapToObj(i -> String.valueOf(i % 10))
                .collect(Collectors.joining("+")),
            new int[]{50, 100, 200, 500}
        );
        assertTrue(result.passed(), "long LR input should be linear (ratio change: " + result.ratioChange() + ")");
    }

    @Test
    void testLinear10Recovery() {
        String grammar = """
            S <- ("(" "x"+ ")")+ ;
            """;
        LinearityResult result = testLinearity(
            grammar,
            "S",
            size -> {
                StringBuilder parts = new StringBuilder();
                for (int i = 0; i < size; i++) {
                    if (i > 0 && i % 10 == 0) {
                        parts.append("(xZx)");  // Error
                    } else {
                        parts.append("(xx)");
                    }
                }
                return parts.toString();
            },
            new int[]{10, 20, 50, 100}
        );
        assertTrue(result.passed(), "recovery should be linear (ratio change: " + result.ratioChange() + ")");
    }
}
