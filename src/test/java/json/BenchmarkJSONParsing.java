package json;

import java.io.IOException;

import org.antlr.v4.runtime.BailErrorStrategy;
import org.antlr.v4.runtime.CharStreams;
import org.antlr.v4.runtime.CommonTokenStream;
import org.antlr.v4.runtime.ConsoleErrorListener;
import org.antlr.v4.runtime.ParserRuleContext;

import squirrel.TestUtils;
import squirrelparser.grammar.Grammar;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.MemoUtils;
import squirrelparser.utils.MetaGrammar;

public class BenchmarkJSONParsing {

    public static long benchmarkAntlr4_json(String input) {
        var startTime = System.nanoTime();
        try {
            // Create a scanner that reads from the input stream passed to us
            var lexer = new json.antlr4.JSONLexer(CharStreams.fromString(input));
            lexer.removeErrorListener(ConsoleErrorListener.INSTANCE);

            CommonTokenStream tokens = new CommonTokenStream(lexer);

            // Create a parser that reads from the scanner
            var parser = new json.antlr4.JSONParser(tokens);
            parser.setErrorHandler(new BailErrorStrategy());
            parser.setBuildParseTree(true);

            // start parsing at the json rule
            @SuppressWarnings("unused")
            ParserRuleContext t = parser.json();

            // System.out.println(Trees.toStringTree(t));

            var elapsedTime = System.nanoTime() - startTime;
            return elapsedTime;

        } catch (Exception e) {
            return -1;
        }
    }

    private static Grammar squirrel_JSONGrammar = MetaGrammar
            .parse(TestUtils.loadResourceFile("json/squirrel/json.peg"));
    static {
        // ClauseUtils.inlineTerminalClauseTrees(squirrel_JSONGrammar);
    }

    public static long benchmarkSquirrel_JSON(String input) {
        var startTime = System.nanoTime();
        var parser = new Parser(squirrel_JSONGrammar);
        var match = parser.parse(input);
        if (match == Match.MISMATCH || match.len < input.length()) {
            System.out.println(MemoUtils.findMaxEndPos(parser));
            return -1;
        }
        var elapsedTime = System.nanoTime() - startTime;
        return elapsedTime;
    }

    public static void main(String[] args) throws IOException {
        var googleJson = TestUtils.loadResourceFile("json-parse-benchmark.json");
        System.out.println(BenchmarkJSONParsing.benchmarkSquirrel_JSON(googleJson) * 1.0e-9 + "\t"
                + BenchmarkJSONParsing.benchmarkAntlr4_json(googleJson) * 1.0e-9);

        var maxDepth = 10; // For small JSON test: 2
        var numIter = 100; // For small JSON test: 1000
        var timeSquirrel = 0L;
        var timeAntlr = 0L;
        var totBytes = 0;
        {
            var jsonGenerator = new JSONGenerator();
            for (int i = 0; i < numIter; i++) {
                var json = jsonGenerator.generateJSON(maxDepth);
                totBytes += json.length();
                // timeSquirrel += TestUtils.findMinTime(BenchmarkJSONParsing::benchmarkSquirrel_JSON, json);
                timeSquirrel += BenchmarkJSONParsing.benchmarkSquirrel_JSON(json);
            }
        }
        {
            var jsonGenerator = new JSONGenerator();
            for (int i = 0; i < numIter; i++) {
                var json = jsonGenerator.generateJSON(maxDepth);
                // timeAntlr += TestUtils.findMinTime(BenchmarkJSONParsing::benchmarkAntlr4_json, json);
                timeAntlr += BenchmarkJSONParsing.benchmarkAntlr4_json(json);
            }
        }
        System.out.println(timeSquirrel * 1.0e-9 + "\t" + timeAntlr * 1.0e-9 + totBytes);
    }
}
