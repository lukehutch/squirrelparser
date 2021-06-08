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
        var input = loadResourceFile("arithmetic.input");
        System.out.println("INPUT:\n\n" + input);

        var grammarSource = loadResourceFile("arithmetic.grammar");
        System.out.println("\nGRAMMAR SOURCE:\n\n" + grammarSource);

        var rewrittenGrammar = MetaGrammar.parse(grammarSource);
        System.out.println("\nREWRITTEN GRAMMAR:\n\n" + rewrittenGrammar);

        var parser = new Parser(rewrittenGrammar, input);
        var match = parser.parse();
        System.out.println("\nPARSE TREE:\n\n" + match.toStringWholeTree(parser.input));

        if (match != Match.NO_MATCH) {
            var ast = new ASTNode(match, parser.input);
            System.out.println("\nAST:\n\n" + ast.toStringWholeTree());
        }
    }
}
