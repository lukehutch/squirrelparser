package json;

import java.io.IOException;

import org.antlr.v4.runtime.BailErrorStrategy;
import org.antlr.v4.runtime.CharStreams;
import org.antlr.v4.runtime.CommonTokenStream;
import org.antlr.v4.runtime.ConsoleErrorListener;
import org.antlr.v4.runtime.ParserRuleContext;

import squirrel.TestUtils;
import squirrelparser.grammar.Grammar;
import squirrelparser.node.ASTNode;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.ClauseUtils;
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
        // System.out.println(match.toStringWholeTree(input));
        //var ast = new ASTNode(match, input);                    // TODO: why does this call take so long?? ***********************
        //        var ast = parser.parseToAST(input);
        
        //System.out.println(ast.toStringWholeTree());

        var elapsedTime = System.nanoTime() - startTime;
        return elapsedTime;
    }

    public static void main(String[] args) throws IOException {
        var json = TestUtils.loadResourceFile("json-parse-benchmark.json");
        var json2 = "{\n" + "    \"glossary\": {\n" + "        \"title\": \"example glossary\",\n"
                + "        \"GlossDiv\": {\n" + "            \"title\": \"S\",\n" + "            \"GlossList\": {\n"
                + "                \"GlossEntry\": {\n" + "                    \"ID\": \"SGML\",\n"
                + "                    \"SortAs\": \"SGML\",\n"
                + "                    \"GlossTerm\": \"Standard Generalized Markup Language\",\n"
                + "                    \"Acronym\": \"SGML\",\n"
                + "                    \"Abbrev\": \"ISO 8879:1986\",\n" + "                    \"GlossDef\": {\n"
                + "                        \"para\": \"A meta-markup language, used to create markup languages such as DocBook.\",\n"
                + "                        \"GlossSeeAlso\": [\"GML\", \"XML\"]\n" + "                    },\n"
                + "                    \"GlossSee\": \"markup\"\n" + "                }\n" + "            }\n"
                + "        }\n" + "    }\n" + "}";

        System.out.println(BenchmarkJSONParsing.benchmarkSquirrel_JSON(json) * 1.0e-9);

        System.out.println(BenchmarkJSONParsing.benchmarkAntlr4_json(json) * 1.0e-9);

    }
}
