package javaparse;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.stream.Collectors;

import org.antlr.v4.runtime.BailErrorStrategy;
import org.antlr.v4.runtime.CharStreams;
import org.antlr.v4.runtime.CommonTokenStream;
import org.antlr.v4.runtime.ConsoleErrorListener;
import org.antlr.v4.runtime.ParserRuleContext;
import org.parboiled.Parboiled;
import org.parboiled.parserunners.ReportingParseRunner;

import javaparse.antlr.Java8Lexer;
import javaparse.antlr.Java8Parser;
import javaparse.parboiled.JavaParser;
import javaparse.squirrel.SquirrelParboiledJavaGrammar;
import squirrel.TestUtils;
import squirrelparser.grammar.Grammar;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.MetaGrammar;

public class BenchmarkJavaParsing {
    // Run this benchmark after first cloning spring-boot into /tmp:
    // cd /tmp ; git clone --depth 1 https://github.com/spring-projects/spring-boot.git
    private static final String sourceCodeRoot = "/tmp/spring-boot";

    private static final List<Path> sourcePaths;
    static {
        // Find all Java files in source tree
        try {
            sourcePaths = Files.find(Paths.get(sourceCodeRoot), 999, (path,
                    attributes) -> path.getFileName().toString().endsWith(".java") && attributes.isRegularFile())
                    .collect(Collectors.toList());
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        var totPaths = sourcePaths.size();
        if (totPaths == 0) {
            throw new RuntimeException("No source code files found");
        }
        System.out.println("Source code files found: " + totPaths);
    }

    //    private static String preprocessSource(String input) {
    //        return input.replaceAll("/\\*.*\\*/", "").replaceAll("//.*\n", "\n").replaceAll("<>", "");
    //    }

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

    public static long benchmarkAntlr(String input) throws IOException {
        var startTime = System.nanoTime();
        try {
            // Create a scanner that reads from the input stream passed to us
            Java8Lexer lexer = new Java8Lexer(CharStreams.fromString(input));
            lexer.removeErrorListener(ConsoleErrorListener.INSTANCE);

            CommonTokenStream tokens = new CommonTokenStream(lexer);

            // Create a parser that reads from the scanner
            Java8Parser parser = new Java8Parser(tokens);
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

    // Squirrel grammars
    private static Grammar squirrelGrammarParboiled_1p6 = SquirrelParboiledJavaGrammar.grammar;
    private static Grammar squirrelGrammarMouse_1p8 = MetaGrammar.parse(TestUtils.loadResourceFile("Java.1.8.peg"));

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

    public static void main(String[] args) throws IOException {
        //long totLen = 0L;
        for (var path : sourcePaths) {
            //totLen += path.toFile().length();
            var input = Files.readString(path);
            // input = preprocessSource(input);

            var timeParb = benchmarkParboiled(input);
            if (timeParb < 0) {
                continue;
            }
            var timeAntlr = benchmarkAntlr(input);
            if (timeAntlr < 0) {
                continue;
            }
            var timeSquirrelParb = benchmarkSquirrelParboiled_1p6(input);
            if (timeSquirrelParb < 0) {
                continue;
            }
            var timeSquirrelMouse = benchmarkSquirrelMouse_1p8(input);
            if (timeSquirrelMouse < 0) {
                continue;
            }
            System.out.println(path + "\t" + input.length() + "\t" + timeParb * 1.0e-9 + "\t" + timeAntlr * 1.0e-9
                    + "\t" + timeSquirrelParb * 1.0e-9 + "\t" + +timeSquirrelMouse * 1.0e-9);
        }
        System.out.println("Finished");
    }
}
