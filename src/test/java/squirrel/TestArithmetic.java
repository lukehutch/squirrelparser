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
import squirrelparser.node.ASTNode;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.MetaGrammar;

public class TestArithmetic {
    private static void tryParsing(Grammar grammar, String input) {
        var parser = new Parser(grammar, input);
        var match = parser.parse();
        if (match == Match.NO_MATCH) {
            throw new IllegalArgumentException();
        }
        var ast = new ASTNode(match, parser.input);
        System.out.println(ast.toStringWholeTree());
    }

    public static void main(String[] args) {
        var grammar1 = MetaGrammar.parse("Program <- Statement+;\n" //
                + "Statement <- var:[a-z]+ '=' Sum ';';\n" //
                + "Sum <- add:(Sum '+' Term) / sub:(Sum '-' Term) / term:Term;\n" //
                + "Term <- num:[0-9]+ / sym:[a-z]+;\n");
        tryParsing(grammar1, "x=a+b-c;");
        tryParsing(grammar1, "x=a-b+c;");

        // This ambiguous grammar is right associative
        var grammar2 = MetaGrammar.parse("E <- sum:(E op:'+' E) / N;\n" //
                + "N <- num:[0-9]+;\n");
        tryParsing(grammar2, "0+1+2+3;");
        // ...but this is left associative:
        var grammar3 = MetaGrammar.parse("E <- sum:(E op:'+' N) / N;\n" //
                + "N <- num:[0-9]+;\n");
        tryParsing(grammar3, "0+1+2+3;");
    }
}
