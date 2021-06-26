package javaparse;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.stream.Collectors;

import squirrel.TestUtils;

public class BenchmarkJavaParsing {
    // Run this benchmark after first cloning spring-boot into /tmp:
    // cd /tmp ; git clone --depth 1 https://github.com/spring-projects/spring-boot.git
    private static final String sourceCodeRoot = "/tmp/spring-boot";

    private static final List<Path> sourcePaths;
    static {
        // Find all Java files in source tree
        try {
            sourcePaths = Files.find(Paths.get(sourceCodeRoot), 999, (path,
                    attributes) -> path.getFileName().toString().endsWith(".java") && attributes.isRegularFile())
                    .collect(Collectors.toList());
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        var totPaths = sourcePaths.size();
        if (totPaths == 0) {
            throw new RuntimeException("No source code files found");
        }
        System.out.println("Source code files found: " + totPaths);
    }

    public static void main(String[] args) throws IOException {
        //long totLen = 0L;
        int numFilesParsed = 0;
        for (var path : sourcePaths) {
            //totLen += path.toFile().length();
            var input = Files.readString(path);

            // Get rid of the diamond operator, since this is a common reason for the Parboiled Java 1.6 grammar
            // to fail to parse a file (the other common reason is the presence of lambdas)
            input = input.replace("<>", "");

            var timeParb = 0L;//TestUtils.findMinTime(JavaParsers::benchmarkParboiled_java, input);
            if (timeParb < 0) {
                continue; // Skips source files with Java 7+ features
            }

            // Run Antlr parse just once, because Antlr has very high cold startup times (taking the minimum
            // across 5 runs is not representative of normal parsing times)
            var timeAntlr_java = 0L;//JavaParsers.benchmarkAntlr_java(input);
            if (timeAntlr_java < 0) {
                continue;
            }
            var timeAntlr_java8 = 0L;//JavaParsers.benchmarkAntlr_java8(input);
            if (timeAntlr_java8 < 0) {
                continue;
            }
            var timeAntlr_java9 = 0L;//JavaParsers.benchmarkAntlr_java9(input);
            if (timeAntlr_java9 < 0) {
                continue;
            }
            var timeSquirrelParb = TestUtils.findMinTime(JavaParsers::benchmarkSquirrel_Parboiled_java1p6, input);
            if (timeSquirrelParb < 0) {
                continue;
            }
            var timeSquirrelMouse = TestUtils.findMinTime(JavaParsers::benchmarkSquirrel_Mouse_java1p8, input);
            if (timeSquirrelMouse < 0) {
                continue;
            }
            numFilesParsed++;
            System.out.println(path + "\t" + input.length() + "\t" + timeParb * 1.0e-9 + "\t"
                    + timeAntlr_java * 1.0e-9 + "\t" + timeAntlr_java8 * 1.0e-9 + "\t" + timeAntlr_java9 * 1.0e-9
                    + "\t" + timeSquirrelParb * 1.0e-9 + "\t" + +timeSquirrelMouse * 1.0e-9);
        }
        System.out.println("Parsed " + numFilesParsed + " files");
    }
}
