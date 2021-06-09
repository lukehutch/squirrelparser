package pikaparser;

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
