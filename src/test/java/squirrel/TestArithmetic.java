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
            var ast = match.toAST(parser.input);
            System.out.println(ast.toStringWholeTree());
        }
    }

    private static void tryParsing(Grammar grammar, String input) {
        tryParsing(grammar, input, true);
    }

    public static void main(String[] args) {
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
//        tryParsing(grammar2, "0+1+2+3;");
//        // ...but this is left associative:
//        var grammar3 = MetaGrammar.parse("E <- sum:(E op:'+' N) / N;\n" //
//                + "N <- num:[0-9]+;\n");
//        tryParsing(grammar3, "0+1+2+3;");

        var grammar4 = MetaGrammar.parse("A <- a:((B !'y') / 'x'); B <- b:(A 'x');");
        tryParsing(grammar4, "xxxy;");

//        var grammar5 = MetaGrammar.parse("A <- a:(B / 'x'); B <- b:(A 'y' / A 'x');");
//        tryParsing(grammar5, "xxyx;");
//
//        var grammar6 = MetaGrammar.parse("A <- a:(B / 'x'); B <- b:(A 'x');");
//        tryParsing(grammar6, "xxx;");

        //        // Benchmark example from https://www.python.org/dev/peps/pep-0617
        //        var grammar7 = MetaGrammar.parse( //
        //                "P <- <WS> (E0 '\\n'?)+;\n" //
        //                        + "E3 <- '(' <WS> E0 <WS> ')';\n" //
        //                        + "E2 <- num:N / E3;\n" //
        //                        + "E1 <- arith:(E1 <WS> op:'*' <WS> E2) / E2;\n" //
        //                        + "E0 <- arith:(E0 <WS> op:'+' <WS> E1) / E1;\n" //
        //                        + "N <- [0-9]+;");
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


        
    }
}
