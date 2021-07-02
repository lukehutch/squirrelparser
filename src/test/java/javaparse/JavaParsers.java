package javaparse;

import org.antlr.v4.runtime.BailErrorStrategy;
import org.antlr.v4.runtime.CharStreams;
import org.antlr.v4.runtime.CommonTokenStream;
import org.antlr.v4.runtime.ConsoleErrorListener;
import org.antlr.v4.runtime.ParserRuleContext;
import org.parboiled.Parboiled;
import org.parboiled.parserunners.ReportingParseRunner;

import javaparse.mouse23.MouseJava14Parser;
import javaparse.parboiled1.JavaParser;
import javaparse.parboiled2.Parboiled2JavaParser;
import javaparse.squirrel.SquirrelParboiledJavaGrammar;
import mouse.runtime.SourceString;
import squirrel.TestUtils;
import squirrelparser.grammar.Grammar;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.MetaGrammar;

public class JavaParsers {

    public static long benchmarkParboiled1_java(String input) {
        var startTime = System.nanoTime();
        var parser = Parboiled.createParser(JavaParser.class);
        parser = parser.newInstance();
        var rootRule = parser.CompilationUnit();
        try {
            var reportingParseRunner = new ReportingParseRunner<>(rootRule);
            var result = reportingParseRunner.run(input);
            if (!result.matched) {
                // This grammar supports only Java 1.6, so diamond operators and lambdas give a syntax error

                //                for (var err : reportingParseRunner.getParseErrors()) {
                //                    var start = err.getStartIndex();
                //                    var end = err.getEndIndex();
                //                    end = Math.min(Math.max(end, start + 80), input.length());
                //                    System.err.println(start + "\t" + end);
                //                    var span = StringUtils.replaceNonASCII(input.substring(start, end));
                //                    System.err.println(span);
                //                }
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

    public static long benchmarkParboiled2_java(String input) {
        var startTime = System.nanoTime();
        var result = Parboiled2JavaParser.parse(input);
        if (result.isFailure()) {
            return -1;
        }
        return System.nanoTime() - startTime;
    }

    public static long benchmarkAntlr4_java(String input) {
        var startTime = System.nanoTime();
        try {
            // Create a scanner that reads from the input stream passed to us
            var lexer = new javaparse.antlr4.java.JavaLexer(CharStreams.fromString(input));
            lexer.removeErrorListener(ConsoleErrorListener.INSTANCE);

            CommonTokenStream tokens = new CommonTokenStream(lexer);

            // Create a parser that reads from the scanner
            var parser = new javaparse.antlr4.java.JavaParser(tokens);
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

    public static long benchmarkAntlr4_java8(String input) {
        var startTime = System.nanoTime();
        try {
            // Create a scanner that reads from the input stream passed to us
            var lexer = new javaparse.antlr4.java8.Java8Lexer(CharStreams.fromString(input));
            lexer.removeErrorListener(ConsoleErrorListener.INSTANCE);

            CommonTokenStream tokens = new CommonTokenStream(lexer);

            // Create a parser that reads from the scanner
            var parser = new javaparse.antlr4.java8.Java8Parser(tokens);
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

    public static long benchmarkAntlr4_java9(String input) {
        var startTime = System.nanoTime();
        try {
            // Create a scanner that reads from the input stream passed to us
            var lexer = new javaparse.antlr4.java9.Java9Lexer(CharStreams.fromString(input));
            lexer.removeErrorListener(ConsoleErrorListener.INSTANCE);

            CommonTokenStream tokens = new CommonTokenStream(lexer);

            // Create a parser that reads from the scanner
            var parser = new javaparse.antlr4.java9.Java9Parser(tokens);
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

    public static long benchmarkMouse23_Java14(String input) {
        var startTime = System.nanoTime();
        var parser = new MouseJava14Parser();
        boolean ok = parser.parse(new SourceString(input));
        if (!ok) {
            return -1;
        }
        var elapsedTime = System.nanoTime() - startTime;
        return elapsedTime;
    }

    private static Grammar squirrelGrammar_Parboiled_java6 = SquirrelParboiledJavaGrammar.grammar;

    public static long benchmarkSquirrel_Parboiled_java6(String input) {
        var startTime = System.nanoTime();
        var parser = new Parser(squirrelGrammar_Parboiled_java6);
        var match = parser.parse(input);
        if (match == Match.MISMATCH || match.len < input.length()) {
            return -1;
        }
        var elapsedTime = System.nanoTime() - startTime;
        return elapsedTime;
    }

    private static Grammar squirrelGrammar_Mouse_java8 = MetaGrammar
            .parse(TestUtils.loadResourceFile("javaparse/squirrel/Mouse_Java.1.8.peg"));

    public static long benchmarkSquirrel_Mouse_java8(String input) {
        var startTime = System.nanoTime();
        var parser = new Parser(squirrelGrammar_Mouse_java8);
        var match = parser.parse(input);
        if (match == Match.MISMATCH || match.len < input.length()) {
            return -1;
        }
        var elapsedTime = System.nanoTime() - startTime;
        return elapsedTime;
    }

    private static Grammar squirrelGrammar_Mouse_java14 = MetaGrammar
            .parse(TestUtils.loadResourceFile("javaparse/squirrel/Mouse_Java.14.peg"));

    public static long benchmarkSquirrel_Mouse_java14(String input) {
        var startTime = System.nanoTime();
        var parser = new Parser(squirrelGrammar_Mouse_java14);
        var match = parser.parse(input);
        if (match == Match.MISMATCH || match.len < input.length()) {
            return -1;
        }
        var elapsedTime = System.nanoTime() - startTime;
        return elapsedTime;
    }
}