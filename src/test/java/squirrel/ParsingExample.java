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

import squirrelparser.node.ASTNode;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.MetaGrammar;

public class ParsingExample {
    public static void main(String[] args) {
        var input = TestUtils.loadResourceFile("arithmetic.input");
        System.out.println("INPUT:\n\n" + input);

        var grammarSource = TestUtils.loadResourceFile("arithmetic.grammar");
        System.out.println("\nGRAMMAR SOURCE:\n\n" + grammarSource);

        var rewrittenGrammar = MetaGrammar.parse(grammarSource);
        System.out.println("\nREWRITTEN GRAMMAR:\n\n" + rewrittenGrammar);

        var parser = new Parser(rewrittenGrammar, input);
        var match = parser.parse();
        if (match == Match.NO_MATCH) {
            System.out.println("\nNO_MATCH");
        } else {
            System.out.println("\nPARSE TREE:\n\n" + match.toStringWholeTree(parser.input));

            var ast = new ASTNode(match, parser.input);
            System.out.println("\nAST:\n\n" + ast.toStringWholeTree());
        }
    }
}
