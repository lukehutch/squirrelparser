package javaparse;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.stream.Collectors;

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

    //    private static String preprocessSource(String input) {
    //        return input.replaceAll("/\\*.*\\*/", "").replaceAll("//.*\n", "\n").replaceAll("<>", "");
    //    }

    public static void main(String[] args) throws IOException {
        //long totLen = 0L;
        for (var path : sourcePaths) {
            //totLen += path.toFile().length();
            var input = Files.readString(path);
            // input = preprocessSource(input);

            var timeParb = JavaParsers.benchmarkParboiled(input);
            if (timeParb < 0) {
                //continue;
            }
            var timeAntlr_java = JavaParsers.benchmarkAntlr_java(input);
            if (timeAntlr_java < 0) {
                //continue;
            }
            var timeAntlr_java8 = JavaParsers.benchmarkAntlr_java8(input);
            if (timeAntlr_java8 < 0) {
                //continue;
            }
            var timeAntlr_java9 = JavaParsers.benchmarkAntlr_java9(input);
            if (timeAntlr_java9 < 0) {
                //continue;
            }
            var timeSquirrelParb = JavaParsers.benchmarkSquirrelParboiled_1p6(input);
            if (timeSquirrelParb < 0) {
                //continue;
            }
            var timeSquirrelMouse = JavaParsers.benchmarkSquirrelMouse_1p8(input);
            if (timeSquirrelMouse < 0) {
                //continue;
            }
            System.out.println(path + "\t" + input.length() + "\t" + timeParb * 1.0e-9 + "\t"
                    + timeAntlr_java * 1.0e-9 + "\t" + timeAntlr_java8 * 1.0e-9 + "\t" + timeAntlr_java9 * 1.0e-9
                    + "\t" + timeSquirrelParb * 1.0e-9 + "\t" + +timeSquirrelMouse * 1.0e-9);
        }
        System.out.println("Finished");
    }
}
