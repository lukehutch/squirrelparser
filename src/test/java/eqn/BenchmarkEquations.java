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
import java.util.function.Function;

import org.antlr.v4.runtime.CharStreams;
import org.antlr.v4.runtime.CommonTokenStream;
import org.parboiled.BaseParser;
import org.parboiled.Parboiled;
import org.parboiled.Rule;
import org.parboiled.annotations.BuildParseTree;
import org.parboiled.parserunners.ReportingParseRunner;

import eqn.antlr.EquationLexer;
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

    public static long benchmarkParboiled(String input) {
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
        var parser = new Parser(grammar, input);
        var match = parser.parse();
        if (match == Match.NO_MATCH || match.len < input.length()) {
            return -1;
        }
        var elapsedTime = System.nanoTime() - startTime;
        return elapsedTime;
    }

    public static long benchmarkAntlr(String input) {
        var startTime = System.nanoTime();

        EquationLexer lexer = new EquationLexer(CharStreams.fromString(input));
        CommonTokenStream tokens = new CommonTokenStream(lexer);
        eqn.antlr.EquationParser parser = new eqn.antlr.EquationParser(tokens);

        @SuppressWarnings("unused")
        var result = parser.eqn();

        var elapsedTime = System.nanoTime() - startTime;
        //if (parser.getNumberOfSyntaxErrors() == 0) {
        return elapsedTime;
        //        }
        //        return -1;
    }

    // Execute 3x, and find the minimum execution time, to try to remove the effect of GC and other hiccups
    private static long findMinTime(Function<String, Long> timerFunction, String input) {
        long minTime = Long.MAX_VALUE;
        for (int i = 0; i < 3; i++) {
            minTime = Math.min(minTime, timerFunction.apply(input));
        }
        return minTime;
    }

    public static void main(String[] args) throws IOException {
        for (int depth = 0; depth < 21; depth++) {
            for (int i = 0; i < 100; i++) {
                var input = EquationGenerator.generateEquation(depth);
                var timeParb = findMinTime(BenchmarkEquations::benchmarkParboiled, input);
                var timeAntlr = 0L; //findMinTime(BenchmarkEquations::benchmarkAntlr, input);
                var timeSquirrel = findMinTime(BenchmarkEquations::benchmarkSquirrel, input);
                System.out.println(depth + "\t" + input.length() + "\t" + timeParb * 1.0e-9 + "\t"
                        + timeAntlr * 1.0e-9 + "\t" + timeSquirrel * 1.0e-9);
            }
        }
        System.out.println("Finished");
    }
}
