package javaparse;

import java.io.ByteArrayOutputStream;
import java.io.FileDescriptor;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.PrintStream;
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

    public static void main(String[] args) throws IOException {
        // One of the parsers writes to stderr, which interrupts the output
        var stderr = new ByteArrayOutputStream();
        System.setErr(new PrintStream(stderr));

        //long totLen = 0L;
        int numFilesParsed = 0;
        int totLen = 0;
        for (var path : sourcePaths) {
            var input = Files.readString(path);

            // Get rid of the diamond operator, since this is a common reason for the Parboiled Java 1.6 grammar
            // to fail to parse a file (the other common reason is the presence of lambdas)
            input = input.replace("<>", "");

            var timeParb1 = JavaParsers.benchmarkParboiled1_java(input);
            if (timeParb1 < 0) {
                continue; // Skips source files with Java 7+ features
            }

            //            var timeParb2 = 0L;//JavaParsers.benchmarkParboiled2_java(input); // Not working
            //            if (timeParb2 < 0) {
            //                continue; // Skips source files with Java 7+ features
            //            }
            var timeAntlr_java = JavaParsers.benchmarkAntlr4_java(input);
            if (timeAntlr_java < 0) {
                continue;
            }
            var timeAntlr_java8 = JavaParsers.benchmarkAntlr4_java8(input);
            if (timeAntlr_java8 < 0) {
                continue;
            }
            var timeAntlr_java9 = JavaParsers.benchmarkAntlr4_java9(input);
            if (timeAntlr_java9 < 0) {
                continue;
            }
            var timeMouse_Java14 = JavaParsers.benchmarkMouse23_Java14(input);
            if (timeMouse_Java14 < 0) {
                continue;
            }
            var timeSquirrel_Parb1_java6 = JavaParsers.benchmarkSquirrel_Parboiled_java6(input);
            if (timeSquirrel_Parb1_java6 < 0) {
                continue;
            }
            var timeSquirrel_Mouse8 = JavaParsers.benchmarkSquirrel_Mouse_java8(input);
            if (timeSquirrel_Mouse8 < 0) {
                continue;
            }
            var timeSquirrel_Mouse14 = JavaParsers.benchmarkSquirrel_Mouse_java14(input);
            if (timeSquirrel_Mouse14 < 0) {
                continue;
            }
            totLen += input.length();
            numFilesParsed++;
            System.out.println(path + "\t" + input.length() + "\t" + timeParb1 * 1.0e-9 //
            /* + "\t" + timeParb2 * 1.0e-9 */
                    + "\t" + timeAntlr_java * 1.0e-9 + "\t" + timeAntlr_java8 * 1.0e-9 + "\t"
                    + timeAntlr_java9 * 1.0e-9 + "\t" + timeMouse_Java14 * 1.0e-9 + "\t"
                    + timeSquirrel_Parb1_java6 * 1.0e-9 + "\t" + +timeSquirrel_Mouse8 * 1.0e-9 + "\t"
                    + +timeSquirrel_Mouse14 * 1.0e-9);
        }
        System.out.println(stderr.toString());
        System.out.println("Parsed " + numFilesParsed + " files, " + totLen + " bytes");

        System.setErr(new PrintStream(new FileOutputStream(FileDescriptor.err)));
    }
}
