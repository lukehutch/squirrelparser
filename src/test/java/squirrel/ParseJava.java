package squirrel;

import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.stream.Collectors;

import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.MemoUtils;
import squirrelparser.utils.MetaGrammar;
import squirrelparser.utils.StringUtils;

public class ParseJava {

    // cd /tmp ; git clone --depth 1 https://github.com/spring-projects/spring-boot.git
    private static final String sourceCodeRoot = "/tmp/spring-boot";

    public static void main(String[] args) throws Exception {
        // Find all Java files in source tree
        var sourcePaths = Files.find(Paths.get(sourceCodeRoot), 999,
                (path, attributes) -> path.getFileName().toString().endsWith(".java") && attributes.isRegularFile())
                .collect(Collectors.toList());
        var totPaths = sourcePaths.size();
        if (totPaths == 0) {
            throw new IllegalArgumentException("No source code files found");
        }
        System.out.println("Source code files found: " + totPaths);

        long startTime = System.nanoTime();
        long totLen = 0L;
        final var grammar = MetaGrammar.parse(TestUtils.loadResourceFile("Java.1.8.peg"));
        for (var path : sourcePaths) {
            totLen += path.toFile().length();
            var input = Files.readString(path);
            var parser = new Parser(grammar, input);
            var match = parser.parse();
            if (match == Match.NO_MATCH) {
                var syntaxErrPos = MemoUtils.findMaxEndPos(parser);
                var syntaxErr = input.substring(syntaxErrPos, Math.min(syntaxErrPos + 180, input.length()));
                System.out.println("Syntax error at position " + syntaxErrPos + " : "
                        + StringUtils.replaceNonASCII(syntaxErr));
                System.out.println("  " + path);
            }
        }
        long endTime = System.nanoTime();
        var totTime = (endTime - startTime) * 1.0e-9;
        System.out.println("Parsed in: " + totTime);
        System.out.println("Files/sec: " + totPaths / totTime);
        System.out.println("Bytes/sec: " + totLen / totTime);

        System.out.println("Finished");
    }

}
