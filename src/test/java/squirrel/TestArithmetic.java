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

import squirrelparser.grammar.Grammar;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.MetaGrammar;

public class TestArithmetic {
    private static void tryParsing(Grammar grammar, String input, boolean printAST) {
        var parser = new Parser(grammar);
        var match = parser.parse(input);
        if (match == Match.MISMATCH) {
            System.out.println("MISMATCH\n");
        } else if (printAST) {
            System.out.println(match.toStringWholeTree(parser.input));
            var ast = match.toAST(parser.input);
            System.out.println(ast.toStringWholeTree());
        }
    }

    private static void tryParsing(Grammar grammar, String input) {
        tryParsing(grammar, input, true);
    }

    public static String unrollGrammar(String ruleName, String ruleClauses, int n) {
        var buf = new StringBuilder();
        for (int i = n - 1; i >= 0; i--) {
            buf.append(ruleName + i + " <- " + ruleClauses.replace(ruleName, i == 0 ? "'-'" : ruleName + (i - 1))
                    + ";\n");
        }
        return buf.toString();
    }

    public static void main(String[] args) {
        Parser.DEBUG = false;

        //        var grammar1 = MetaGrammar.parse("Program <- Statement+;\n" //
        //                + "Statement <- var:[a-z]+ '=' Sum ';';\n" //
        //                + "Sum <- add:(Sum '+' Term) / sub:(Sum '-' Term) / term:Term;\n" //
        //                + "Term <- num:[0-9]+ / sym:[a-z]+;\n");
        //        tryParsing(grammar1, "x=a+b-c;");
        //        tryParsing(grammar1, "x=a-b+c;");
        //
        //        // This ambiguous grammar is right associative
        //        var grammar2 = MetaGrammar.parse("E <- sum:(E op:'+' E) / N;\n" //
        //                + "N <- num:[0-9]+;\n");
        //        tryParsing(grammar2, "0+1+2+3");
        //        // ...but this is left associative:
        //        var grammar3 = MetaGrammar.parse("E <- sum:(E op:'+' N) / N;\n" //
        //                + "N <- num:[0-9]+;\n");
        //        tryParsing(grammar3, "0+1+2+3");
        //        // ...and this explicitly right-associative grammar has a different parse tree:
        //        var grammar2 = MetaGrammar.parse("E <- sum:(N op:'+' E) / N;\n" //
        //                + "N <- num:[0-9]+;\n");
        //        tryParsing(grammar2, "0+1+2+3");

        //        // Input-dependent left recursion:
        //        tryParsing(MetaGrammar.parse("A <- B / 'z'; B <- ('x' A / A 'y');"), "xxzyyy");

        // tryParsing(MetaGrammar.parse("A <- a:(B / 'x'); B <- b:(A 'y' / A 'x');"), "xxyx");

        tryParsing(MetaGrammar.parse("A <- 'x'? (A 'y' / A / 'y');"), "xxyyy");

        //        // Even though the subclauses take turns not matching, the length of the matching subclause gets longer
        //        // each time, so there's no problem. But for the Pika parser, it stops when (A 'y') can't mismatch,
        //        // due to memoization.
        //        tryParsing(MetaGrammar.parse("A <- a:(A 'y' / A 'x' / ());"), "xxyx");
        //
        //        // This grammar shows the same problem as the pika parser when comparing match lengths, because RuleRefs
        //        // are memoized, and memoized matches can't become mismatches. But when only checking for *unique* match
        //        // lengths, it works fine in the squirrel parser.
        //        tryParsing(MetaGrammar.parse("A <- a:(B / C / ()); B <- A 'y'; C <- A 'x';"), "xxyx");
        //
        //        // Here the rule never fails over to 'x', because iterative expansion of a left recursive cycle follows
        //        // the same rules as memoization, which is to stop at the first mismatch, or when the match length
        //        // decreases (which is this case), and then discard the last failure to improve the match.
        //        // When requiring unique match lengths, this is well-defined to not repeat the `x` match twice, so
        //        // the correct answer here is `xx`, which is what squirrel gives.
        //        tryParsing(MetaGrammar.parse("A <- a:((A 'x' !'y') / 'x');"), "xxxy");
        //
        //        //        // This will still exhibit the parse tree cycle behavior, because it has no left recursion.
        //        //        for (int i = 1; i < 10; i++) {
        //        //            var ug = unrollGrammar("A", "a:((A 'x' !'y') / 'x')", i);
        //        //            System.out.println(ug);
        //        //            tryParsing(MetaGrammar.parse(ug), "xxxxy");
        //        //        }
        //
        //        var grammar6 = MetaGrammar.parse("A <- a:(B / 'x'); B <- b:(A 'x');");
        //        tryParsing(grammar6, "xxx");

        //        // This grammar requires monotonic length increase, and does not work with unique lengths when there's at least one '?' 
        //        var grammar = MetaGrammar.parse("A <- a:(B 'y'); B <- b:((B / seed:\"x?\") '?') / f:'x';");
        //        tryParsing(grammar, "xy");
        //        tryParsing(grammar, "x?y");
        //        tryParsing(grammar, "x??y");

        //        // Doesn't use left recursion
        //        for (var i = 1; i < 10; i++) {
        //            var grammar = MetaGrammar
        //                    .parse("A <- B" + (i - 1) + " 'y'; C <- x:'x'; " + unrollGrammar("B", "q:(B / C) '?' / C", i));
        //            System.out.println("************ " + i + "\n");
        //            tryParsing(grammar, "xy");
        //            tryParsing(grammar, "x?y");
        //            tryParsing(grammar, "x??y");
        //            tryParsing(grammar, "x???y");
        //            tryParsing(grammar, "x????y");
        //        }

        //        // Benchmark example from https://www.python.org/dev/peps/pep-0617
        //        // CPython parser time to beat:
        //        // - Just parsing and throwing away the internal AST takes 1.16 seconds with a max RSS of 681 MiB.
        //        // - Parsing and converting to ast.AST takes 6.34 seconds, max RSS 1029 MiB.
        //        // Squirrel time: 0.68 sec
        //        Parser.DEBUG = true;
        //        var grammar7 = MetaGrammar.parse( //
        //                "P <- <WS> (E0 '\\n'?)+;\n" //
        //                        + "E3 <- '(' <WS> E0 <WS> ')';\n" //
        //                        + "E2 <- num:[0-9]+ / E3;\n" //
        //                        + "E1 <- arith:(E1 <WS> op:'*' <WS> E2) / E2;\n" //
        //                        + "E0 <- arith:(E0 <WS> op:'+' <WS> E1) / E1;\n");
        //        Parser.DEBUG = false;
        //        var pyExamp = new String[] {
        //                "1 + 2 + 4 + 5 + 6 + 7 + 8 + 9 + 10 + ((((((11 * 12 * 13 * 14 * 15 + 16 * 17 + 18 * 19 * 20))))))",
        //                "2*3 + 4*5*6", "12 + (2 * 3 * 4 * 5 + 6 + 7 * 8)" };
        //        var buf = new StringBuilder();
        //        for (int i = 0; i < 100_000; i++) {
        //            buf.append(pyExamp[i % 3]);
        //            buf.append('\n');
        //        }
        //        var input = buf.toString();
        //        long startTime = System.nanoTime();
        //        tryParsing(grammar7, input, false);
        //        System.out.println((System.nanoTime() - startTime) * 1.0e-9);

        //        var grammar8 = MetaGrammar.parse("A <- \"a \" B \"monkeyapples\"; B <- \"million \" / \"million monkey\";");
        //        tryParsing(grammar8, "a million monkeyapples");
        //
        //        var grammar9 = MetaGrammar.parse("A <- (A 'y') / 'x';");
        //        tryParsing(grammar9, "xy");

        // Example of multiple interlocking left recursive cycles, from:
        // https://github.com/PhilippeSigaud/Pegged/wiki/Left-Recursion
        var grammar10 = MetaGrammar.parse( //
                "S <- E;\n" //
                        + "E <- F 'n' / 'n';\n" //
                        + "F <- E '+' I* / G '-';\n" //
                        + "G <- H 'm' / E;\n" //
                        + "H <- G 'l';\n" //
                        + "I <- '(' A+ ')';\n" //
                        + "A <- 'a';");
        tryParsing(grammar10, "nlm-n+(aaa)n");
        //        var grammar11 = MetaGrammar.parse( //
        //                "M <- L;" //
        //                        + "L <- P \".x\" / 'x';" //
        //                        + "P <- P \"(n)\" / L;");
        //        tryParsing(grammar11, "x.x(n)(n).x.x");

    }
}
