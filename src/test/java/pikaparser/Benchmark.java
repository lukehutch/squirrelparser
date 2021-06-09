package pikaparser;

import java.io.IOException;
import java.net.URISyntaxException;
import java.util.Arrays;

import org.junit.Test;

import parboiled.ParboiledJavaGrammar;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.MetaGrammar;

public class Benchmark {
    @Test
    public void arithmetic_example_benchmark() throws IOException, URISyntaxException {
        final var grammarSpec = TestUtils.loadResourceFile("arithmetic.grammar");
        final var input = TestUtils.loadResourceFile("arithmetic.input");

        executeInTimedLoop(() -> {
            var match = new Parser(MetaGrammar.parse(grammarSpec), input).parse();
            if (match == Match.NO_MATCH) {
                throw new IllegalArgumentException("Did not match input");
            }
        }, "arithmetic");
    }

    @Test
    public void grammar_loading_benchmark() throws IOException, URISyntaxException {
        final var grammarSpec = TestUtils.loadResourceFile("Java.1.8.peg");
        executeInTimedLoop(() -> {
            MetaGrammar.parse(grammarSpec);
        }, "java-grammar");
    }

    @Test
    public void java_parsing_benchmark_1() throws IOException, URISyntaxException {
        final var grammarSpec = TestUtils.loadResourceFile("Java.1.8.peg");
        final var input = TestUtils.loadResourceFile("GrammarUtils.java");

        final var grammar = MetaGrammar.parse(grammarSpec);

        executeInTimedLoop(() -> {
            var parser = new Parser(grammar, input);
            var match = parser.parse();
            if (match == Match.NO_MATCH) {
                throw new IllegalArgumentException("Did not match input");
            }
        }, "java-parse-1");
    }

    @Test
    public void java_parsing_benchmark_2() throws IOException, URISyntaxException {
        final var grammar = ParboiledJavaGrammar.grammar;
        final var input = TestUtils.loadResourceFile("GrammarUtils.java");

        executeInTimedLoop(() -> {
            var parser = new Parser(grammar, input);
            var match = parser.parse();
            if (match == Match.NO_MATCH) {
                throw new IllegalArgumentException("Did not match input");
            }
        }, "java-parse-2");
    }

    private static <T> void executeInTimedLoop(Runnable toExecute, String benchmarkName) {
        final long[] results = new long[100];
        for (int i = 0; i < 100; i++) {
            final long start = System.nanoTime();
            toExecute.run();
            results[i] = System.nanoTime() - start;
        }

        System.out.println("\n\n\n===================== RESULTS FOR " + benchmarkName + "=====================");
        System.out.println(Arrays.stream(results).mapToDouble(nano -> nano / 1_000_000_000.0).summaryStatistics());
    }
}
