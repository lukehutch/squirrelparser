package eqn;

import java.io.IOException;

import org.antlr.v4.runtime.CharStreams;
import org.antlr.v4.runtime.CommonTokenStream;
import org.parboiled.BaseParser;
import org.parboiled.Parboiled;
import org.parboiled.Rule;
import org.parboiled.annotations.BuildParseTree;
import org.parboiled.parserunners.ReportingParseRunner;

import eqn.antlr4.EquationLexer;
import eqn.mouse.MouseEqnLeftRecParser;
import eqn.mouse.MouseEqnParser;
import eqn.parboiled2.Parboiled2EqnParser;
import mouse.runtime.SourceString;
import squirrelparser.grammar.Grammar;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.MetaGrammar;

public class BenchmarkEquations {

    @BuildParseTree
    public static class EquationParser extends BaseParser<Object> {
        public Rule Eqn() {
            return Prec0();
        }

        Rule Prec4() {
            return Sequence('(', Prec0(), ')');
        }

        Rule Prec3() {
            return FirstOf(OneOrMore(CharRange('0', '9')), Prec4());
        }

        Rule Prec2() {
            return FirstOf(Sequence('-', Prec3()), Prec3());
        }

        Rule Prec1() {
            return FirstOf(Sequence(Prec2(), FirstOf('*', '/'), Prec2()), Prec2());
        }

        Rule Prec0() {
            return FirstOf(Sequence(Prec1(), FirstOf('+', '-'), Prec1()), Prec1());
        }
    }

    public static long benchmarkParboiled1(String input) {
        var parser = Parboiled.createParser(EquationParser.class);
        var startTime = System.nanoTime();
        parser = parser.newInstance();
        var rootRule = parser.Eqn();
        try {
            var result = new ReportingParseRunner<>(rootRule).run(input);
            if (!result.matched) {
                //                    System.out.printf(
                //                            "--------------------------------------------------> Parse error(s) in file '%s':\n%s",
                //                            filename, printParseErrors(result));
                //                    throw new IOException("Parse error");
            } else {
                return System.nanoTime() - startTime;
            }
        } catch (Exception e) {
            //                err = e.getMessage();
        }
        return -1;
    }

    public static long benchmarkParboiled2(String input) {
        var startTime = System.nanoTime();
        var result = Parboiled2EqnParser.parse(input);
        if (!result.isSuccess()) {
            System.out.println(input + "\n" + result);
            System.exit(1);
            return -1L;
        }
        return System.nanoTime() - startTime;
    }

    public static long benchmarkAntlr4(String input) {
        var startTime = System.nanoTime();

        EquationLexer lexer = new EquationLexer(CharStreams.fromString(input));
        CommonTokenStream tokens = new CommonTokenStream(lexer);
        eqn.antlr4.EquationParser parser = new eqn.antlr4.EquationParser(tokens);

        @SuppressWarnings("unused")
        var result = parser.eqn();

        var elapsedTime = System.nanoTime() - startTime;
        //if (parser.getNumberOfSyntaxErrors() == 0) {
        return elapsedTime;
        //        }
        //        return -1;
    }

    public static long benchmarkMouse23(String input) {
        var startTime = System.nanoTime();
        var parser = new MouseEqnParser();
        boolean ok = parser.parse(new SourceString(input));
        if (!ok) {
            return -1;
        }
        var elapsedTime = System.nanoTime() - startTime;
        return elapsedTime;
    }

    public static long benchmarkMouse23LeftRec(String input) {
        var startTime = System.nanoTime();
        var parser = new MouseEqnLeftRecParser();
        boolean ok = parser.parse(new SourceString(input));
        if (!ok) {
            return -1;
        }
        var elapsedTime = System.nanoTime() - startTime;
        return elapsedTime;
    }

    private static final Grammar SQUIRREL_GRAMMAR = MetaGrammar.parse( //
            "Eqn <- Prec0;\n" //
                    + "Prec4 <- '(' Prec0 ')';\n" //
                    + "Prec3 <- [0-9]+ / Prec4;\n" //
                    + "Prec2 <- ('-' Prec3) / Prec3;\n" //
                    + "Prec1 <- (Prec2 ('*' / '/') Prec2) / Prec2;\n" //
                    + "Prec0 <- (Prec1 ('+' / '-') Prec1) / Prec1;");

    private static final Grammar SQUIRREL_GRAMMAR_LEFT_REC = MetaGrammar.parse( //
            "Eqn <- Prec0;\n" //
                    + "Prec4 <- '(' Prec0 ')';\n" //
                    + "Prec3 <- [0-9]+ / Prec4;\n" //
                    + "Prec2 <- ('-' (Prec2 / Prec3)) / Prec3;\n" //
                    + "Prec1 <- (Prec1 ('*' / '/') Prec2) / Prec2;\n" //
                    + "Prec0 <- (Prec0 ('+' / '-') Prec1) / Prec1;");

    public static long benchmarkSquirrel(String input) {
        var grammar = SQUIRREL_GRAMMAR;
        var startTime = System.nanoTime();
        var parser = new Parser(grammar);
        var match = parser.parse(input);
        if (match == Match.MISMATCH || match.len < input.length()) {
            return -1;
        }
        var elapsedTime = System.nanoTime() - startTime;
        return elapsedTime;
    }

    public static long benchmarkSquirrelLeftRec(String input) {
        var grammar = SQUIRREL_GRAMMAR_LEFT_REC;
        var startTime = System.nanoTime();
        var parser = new Parser(grammar);
        var match = parser.parse(input);
        if (match == Match.MISMATCH || match.len < input.length()) {
            return -1;
        }
        var elapsedTime = System.nanoTime() - startTime;
        return elapsedTime;
    }

    public static void main(String[] args) throws IOException {
        var maxDepth = 10;
        var totSquirrel = 0.0;
        var totSquirrelLeftRec = 0.0;
        var totMouse = 0.0;
        var totMouseLeftRec = 0.0;
        var totAntlr4 = 0.0;
        var totParb1 = 0.0;
        var totParb2 = 0.0;
        {
            System.out.println("\nSquirrel: ======================");
            var eq = new EquationGenerator();
            for (int depth = 0; depth < maxDepth; depth++) {
                for (int i = 0; i < 100; i++) {
                    var input = eq.generateEquation(depth);
                    var time = benchmarkSquirrel(input);
                    System.out.println(depth + "\t" + input.length() + "\t" + time * 1.0e-9);
                    totSquirrel += time;
                }
            }
        }
        {
            // Squirrel runs at 0.6x the speed with the left recursive grammar on the same inputs
            // (this is the overhead of expanding every left argument one extra time in every position)
            // -- when left recursion is rare, the overhead will be lower.
            System.out.println("\nSquirrel Left Rec: ======================");
            var eq = new EquationGenerator();
            for (int depth = 0; depth < maxDepth; depth++) {
                for (int i = 0; i < 100; i++) {
                    var input = eq.generateEquation(depth);
                    var time = benchmarkSquirrelLeftRec(input);
                    System.out.println(depth + "\t" + input.length() + "\t" + time * 1.0e-9);
                    totSquirrelLeftRec += time;
                }
            }
        }
        {
            System.out.println("\nMouse: ======================");
            var eq = new EquationGenerator();
            for (int depth = 0; depth < maxDepth; depth++) {
                for (int i = 0; i < 100; i++) {
                    var input = eq.generateEquation(depth);
                    var time = benchmarkMouse23(input);
                    System.out.println(depth + "\t" + input.length() + "\t" + time * 1.0e-9);
                    totMouse += time;
                }
            }
        }
        {
            // Mouse runs 1.06x faster with the left recursive grammar on the same inputs.. no idea why.
            // Memoization makes no difference for this example.
            System.out.println("\nMouse Left Rec: ======================");
            var eq = new EquationGenerator();
            for (int depth = 0; depth < maxDepth; depth++) {
                for (int i = 0; i < 100; i++) {
                    var input = eq.generateEquation(depth);
                    var time = benchmarkMouse23LeftRec(input);
                    System.out.println(depth + "\t" + input.length() + "\t" + time * 1.0e-9);
                    totMouseLeftRec += time;
                }
            }
        }
        //        {
        //            System.out.println("\nAntlr: ======================");
        //            var eq = new EquationGenerator();
        //            for (int depth = 0; depth < maxDepth; depth++) {
        //                for (int i = 0; i < 100; i++) {
        //                    var input = eq.generateEquation(depth);
        //                    var time = benchmarkAntlr4(input);
        //                    System.out.println(depth + "\t" + input.length() + "\t" + time * 1.0e-9);
        //                    totAntlr4 += time;
        //                }
        //            }
        //        }
        //        {
        //            System.out.println("\nParboiled1: ======================");
        //            var eq = new EquationGenerator();
        //            for (int depth = 0; depth < maxDepth; depth++) {
        //                for (int i = 0; i < 100; i++) {
        //                    var input = eq.generateEquation(depth);
        //                    var time = benchmarkParboiled1(input);
        //                    System.out.println(depth + "\t" + input.length() + "\t" + time * 1.0e-9);
        //                    totParb1 += time;
        //                }
        //            }
        //        }
        //        {
        //            System.out.println("\nParboiled2: ======================");
        //            var eq = new EquationGenerator();
        //            for (int depth = 0; depth < maxDepth; depth++) {
        //                for (int i = 0; i < 100; i++) {
        //                    var input = eq.generateEquation(depth);
        //                    var time = benchmarkParboiled2(input);
        //                    System.out.println(depth + "\t" + input.length() + "\t" + time * 1.0e-9);
        //                    totParb2 += time;
        //                }
        //            }
        //        }
        System.out.println("\nTOT:\n\n" + totSquirrel * 1.0e-9 + "\t" + totSquirrelLeftRec * 1.0e-9 + "\t"
                + totMouse * 1.0e-9 + "\t" + totMouseLeftRec * 1.0e-9 + "\t" + totAntlr4 * 1.0e-9 + "\t"
                + totParb1 * 1.0e-9 + "\t" + totParb2 * 1.0e-9);
    }
}
