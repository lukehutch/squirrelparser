package squirrelparser.main;

import java.io.IOException;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Objects;

import squirrelparser.node.ASTNode;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.MetaGrammar;

public class Main {

    static String loadResourceFile(String filename) throws IOException, URISyntaxException {
        final var resource = Main.class.getClassLoader().getResource(filename);
        final var resourceURI = Objects.requireNonNull(resource).toURI();
        return Files.readString(Paths.get(resourceURI));
    }

    public static void main(String[] args) throws Exception {
        var grammar = MetaGrammar.parse(loadResourceFile("arithmetic.grammar"));
        System.out.println("Grammar:\n" + grammar);

        var input = loadResourceFile("arithmetic.input");
        System.out.println("\nInput:\n" + input);

        var parser = new Parser(grammar, input);
        var match = parser.parse();
        System.out.println("\nParse tree:\n" + match.toStringWholeTree(parser.input));

        if (match != Match.NO_MATCH) {
            var ast = new ASTNode(match, parser.input);
            System.out.println("\nAST:\n" + ast.toStringWholeTree());
        }
    }
}
