package javaparse;

import java.io.IOException;

import org.antlr.v4.runtime.BailErrorStrategy;
import org.antlr.v4.runtime.CharStreams;
import org.antlr.v4.runtime.CommonTokenStream;
import org.antlr.v4.runtime.ConsoleErrorListener;
import org.antlr.v4.runtime.ParserRuleContext;
import org.parboiled.Parboiled;
import org.parboiled.parserunners.ReportingParseRunner;

import javaparse.parboiled.JavaParser;
import javaparse.squirrel.SquirrelParboiledJavaGrammar;
import squirrel.TestUtils;
import squirrelparser.grammar.Grammar;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.MetaGrammar;

public class JavaParsers {

    public static long benchmarkParboiled(String input) throws IOException {
        var startTime = System.nanoTime();
        var parser = Parboiled.createParser(JavaParser.class);
        parser = parser.newInstance();
        var rootRule = parser.CompilationUnit();
        try {
            var result = new ReportingParseRunner<>(rootRule).run(input);
            if (!result.matched) {
                return -1;
            } else {
                var elapsedTime = System.nanoTime() - startTime;
                //                String parseTree = ParseTreeUtils.printNodeTree(result);
                //                System.out.println(parseTree);
                return elapsedTime;
            }
        } catch (Exception e) {
            return -1;
        }
    }

    public static long benchmarkAntlr_java(String input) throws IOException {
        var startTime = System.nanoTime();
        try {
            // Create a scanner that reads from the input stream passed to us
            var lexer = new javaparse.antlr.java.JavaLexer(CharStreams.fromString(input));
            lexer.removeErrorListener(ConsoleErrorListener.INSTANCE);

            CommonTokenStream tokens = new CommonTokenStream(lexer);

            // Create a parser that reads from the scanner
            var parser = new javaparse.antlr.java.JavaParser(tokens);
            parser.setErrorHandler(new BailErrorStrategy());
            parser.setBuildParseTree(true);

            // start parsing at the compilationUnit rule
            @SuppressWarnings("unused")
            ParserRuleContext t = parser.compilationUnit();

            // System.out.println(Trees.toStringTree(t));

            var elapsedTime = System.nanoTime() - startTime;
            return elapsedTime;

        } catch (Exception e) {
            return -1;
        }
    }

    public static long benchmarkAntlr_java8(String input) throws IOException {
        var startTime = System.nanoTime();
        try {
            // Create a scanner that reads from the input stream passed to us
            var lexer = new javaparse.antlr.java8.Java8Lexer(CharStreams.fromString(input));
            lexer.removeErrorListener(ConsoleErrorListener.INSTANCE);

            CommonTokenStream tokens = new CommonTokenStream(lexer);

            // Create a parser that reads from the scanner
            var parser = new javaparse.antlr.java8.Java8Parser(tokens);
            parser.setErrorHandler(new BailErrorStrategy());
            parser.setBuildParseTree(true);

            // start parsing at the compilationUnit rule
            @SuppressWarnings("unused")
            ParserRuleContext t = parser.compilationUnit();

            // System.out.println(Trees.toStringTree(t));

            var elapsedTime = System.nanoTime() - startTime;
            return elapsedTime;

        } catch (Exception e) {
            return -1;
        }
    }

    public static long benchmarkAntlr_java9(String input) throws IOException {
        var startTime = System.nanoTime();
        try {
            // Create a scanner that reads from the input stream passed to us
            var lexer = new javaparse.antlr.java9.Java9Lexer(CharStreams.fromString(input));
            lexer.removeErrorListener(ConsoleErrorListener.INSTANCE);

            CommonTokenStream tokens = new CommonTokenStream(lexer);

            // Create a parser that reads from the scanner
            var parser = new javaparse.antlr.java9.Java9Parser(tokens);
            parser.setErrorHandler(new BailErrorStrategy());
            parser.setBuildParseTree(true);

            // start parsing at the compilationUnit rule
            @SuppressWarnings("unused")
            ParserRuleContext t = parser.compilationUnit();

            // System.out.println(Trees.toStringTree(t));

            var elapsedTime = System.nanoTime() - startTime;
            return elapsedTime;

        } catch (Exception e) {
            return -1;
        }
    }

    private static Grammar squirrelGrammarParboiled_1p6 = SquirrelParboiledJavaGrammar.grammar;

    public static long benchmarkSquirrelParboiled_1p6(String input) throws IOException {
        var startTime = System.nanoTime();
        var parser = new Parser(squirrelGrammarParboiled_1p6, input);
        var match = parser.parse();
        if (match == Match.NO_MATCH) {
            System.out.println("Syntax error");
            return -1;
        }
        var elapsedTime = System.nanoTime() - startTime;
        return elapsedTime;
    }

    private static Grammar squirrelGrammarMouse_1p8 = MetaGrammar.parse(TestUtils.loadResourceFile("Java.1.8.peg"));

    public static long benchmarkSquirrelMouse_1p8(String input) throws IOException {
        var startTime = System.nanoTime();
        var parser = new Parser(squirrelGrammarMouse_1p8, input);
        var match = parser.parse();
        if (match == Match.NO_MATCH) {
            System.out.println("Syntax error");
            return -1;
        }
        var elapsedTime = System.nanoTime() - startTime;
        return elapsedTime;
    }

}
