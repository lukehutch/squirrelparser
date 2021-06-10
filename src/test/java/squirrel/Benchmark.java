//
// This file is part of the squirrel parser reference implementation:
//
//     https://github.com/lukehutch/squirrelparser
//
// This software is provided under the MIT license:
//
// Copyright 2021 Luke A. D. Hutchison
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions
// of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
// TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//
package squirrel;

import java.io.IOException;
import java.net.URISyntaxException;
import java.util.Arrays;

import org.junit.Test;

import javaparse.squirrel.SquirrelParboiledJavaGrammar;
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
        final var grammarSpec = TestUtils.loadResourceFile("javaparse/squirrel/Java.1.8.peg");
        executeInTimedLoop(() -> {
            MetaGrammar.parse(grammarSpec);
        }, "java-grammar");
    }

    @Test
    public void java_parsing_benchmark_mouse_1p8() throws IOException, URISyntaxException {
        final var grammarSpec = TestUtils.loadResourceFile("Java.1.8.peg");
        final var grammar = MetaGrammar.parse(grammarSpec);

        final var input = TestUtils.loadResourceFile("TestJavaClass.java");

        executeInTimedLoop(() -> {
            var parser = new Parser(grammar, input);
            var match = parser.parse();
            if (match == Match.NO_MATCH) {
                throw new IllegalArgumentException("Did not match input");
            }
        }, "java-parse-1");
    }

    @Test
    public void java_parsing_benchmark_parb_1p6() throws IOException, URISyntaxException {
        final var grammar = SquirrelParboiledJavaGrammar.grammar;
        final var input = TestUtils.loadResourceFile("TestJavaClass.java");

        executeInTimedLoop(() -> {
            var parser = new Parser(grammar, input);
            var match = parser.parse();
            if (match == Match.NO_MATCH) {
                throw new IllegalArgumentException("Did not match input");
            }
        }, "java-parse-2");
    }

    @Test
    public void java_parsing_benchmark_many_strings_concat() throws IOException, URISyntaxException {
        final var grammarSpec = TestUtils.loadResourceFile("Java.1.8.peg");
        final var grammar = MetaGrammar.parse(grammarSpec);

        final var input = TestUtils.loadResourceFile("ManyStringsConcat.java");

        executeInTimedLoop(() -> {
            var parser = new Parser(grammar, input);
            var match = parser.parse();
            if (match == Match.NO_MATCH) {
                throw new IllegalArgumentException("Did not match input");
            }
        }, "java-parse-many-strings-concat");
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
