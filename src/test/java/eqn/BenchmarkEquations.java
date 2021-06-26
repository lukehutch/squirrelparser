package eqn;

import static squirrelparser.utils.MetaGrammar.assignRuleName;
import static squirrelparser.utils.MetaGrammar.c;
import static squirrelparser.utils.MetaGrammar.cRange;
import static squirrelparser.utils.MetaGrammar.first;
import static squirrelparser.utils.MetaGrammar.oneOrMore;
import static squirrelparser.utils.MetaGrammar.ruleRef;
import static squirrelparser.utils.MetaGrammar.seq;

import java.io.IOException;
import java.util.Arrays;

import org.antlr.v4.runtime.CharStreams;
import org.antlr.v4.runtime.CommonTokenStream;
import org.parboiled.BaseParser;
import org.parboiled.Parboiled;
import org.parboiled.Rule;
import org.parboiled.annotations.BuildParseTree;
import org.parboiled.parserunners.ReportingParseRunner;

import eqn.antlr4.EquationLexer;
import eqn.parboiled2.Parboiled2EqnParser;
import squirrelparser.grammar.Grammar;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

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

    public static long benchmarkSquirrel(String input) {
        var grammar = new Grammar(Arrays.asList( //
                assignRuleName("Eqn", ruleRef("Prec0")), //
                assignRuleName("Prec4", seq(c('('), ruleRef("Prec0"), c(')'))), //
                assignRuleName("Prec3", first(oneOrMore(cRange('0', '9')), ruleRef("Prec4"))), //
                assignRuleName("Prec2", first(seq(c('-'), ruleRef("Prec3")), ruleRef("Prec3"))), //
                assignRuleName("Prec1",
                        first(seq(ruleRef("Prec2"), first(c('*'), c('/')), ruleRef("Prec2")), ruleRef("Prec2"))),
                assignRuleName("Prec0",
                        first(seq(ruleRef("Prec1"), first(c('+'), c('-')), ruleRef("Prec1")), ruleRef("Prec1")))));

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
        var totSquirrel = 0.0;
        var totAntlr4 = 0.0;
        var totParb1 = 0.0;
        var totParb2 = 0.0;
        {
            System.out.println("\nSquirrel: ======================");
            var eq = new EquationGenerator();
            for (int depth = 0; depth < 20; depth++) {
                for (int i = 0; i < 100; i++) {
                    var input = eq.generateEquation(depth);
                    var time = benchmarkSquirrel(input);
                    System.out.println(depth + "\t" + input.length() + "\t" + time * 1.0e-9);
                    totSquirrel += time;
                }
            }
        }
        //        {
        //            System.out.println("\nAntlr: ======================");
        //            var eq = new EquationGenerator();
        //            for (int depth = 0; depth < 20; depth++) {
        //                for (int i = 0; i < 100; i++) {
        //                    var input = eq.generateEquation(depth);
        //                    var time = benchmarkAntlr(input);
        //                    System.out.println(depth + "\t" + input.length() + "\t" + time * 1.0e-9);
        //                    totAntlr4 += time;
        //                }
        //            }
        //        }
        //        {
        //      System.out.println("\nParboiled1: ======================");
        //      var eq = new EquationGenerator();
        //      for (int depth = 0; depth < 14; depth++) {
        //          for (int i = 0; i < 100; i++) {
        //              var input = eq.generateEquation(depth);
        //              var time = benchmarkParboiled1(input);
        //              System.out.println(depth + "\t" + input.length() + "\t" + time * 1.0e-9);
        //              totParb1 += time;
        //          }
        //      }
        //  }
        {
            System.out.println("\nParboiled2: ======================");
            var eq = new EquationGenerator();
            for (int depth = 0; depth < 14; depth++) {
                for (int i = 0; i < 100; i++) {
                    var input = eq.generateEquation(depth);
                    var time = benchmarkParboiled2(input);
                    System.out.println(depth + "\t" + input.length() + "\t" + time * 1.0e-9);
                    totParb2 += time;
                }
            }
        }
        System.out.println("\nTOT:\n\n" + totSquirrel * 1.0e-9 + "\t" + totAntlr4 * 1.0e-9 + "\t"
                + totParb1 * 1.0e-9 + "\t" + totParb2 * 1.0e-9);
    }
}
