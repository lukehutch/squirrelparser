package squirrel;

import java.io.IOException;

import javaparse.JavaParsers;

public class TestJavaParsing {
    public static void main(String[] args) throws IOException {
        var input = TestUtils.loadResourceFile("TestJavaClass.java");
        //var input = "class X { List<String> xs = new ArrayList<>(); }";
        //var input = "classX{List<String>xs=newArrayList();}";

        // Get rid of the diamond operator, since this is a common reason for the Parboiled Java 1.6 grammar
        // to fail to parse a file (the other common reason is the presence of lambdas)
        input = input.replace("<>", "");

//        var timeParb1 = TestUtils.findMinTime(JavaParsers::benchmarkParboiled1_java, input);
//
//        var timeParb2 = TestUtils.findMinTime(JavaParsers::benchmarkParboiled2_java, input);
//
//        //        var result = Parboiled2JavaParser.parse(input);
//        //        System.out.println(result);
//
//        // Run Antlr parse just once, because Antlr has very high cold startup times (taking the minimum
//        // across 5 runs is not representative of normal parsing times)
//        var timeAntlr_java = JavaParsers.benchmarkAntlr4_java(input);
//
//        var timeAntlr_java8 = JavaParsers.benchmarkAntlr4_java8(input);
//
//        var timeAntlr_java9 = JavaParsers.benchmarkAntlr4_java9(input);
//
//        var timeSquirrelParb = TestUtils.findMinTime(JavaParsers::benchmarkSquirrel_Parboiled_java1p6, input);

        var timeSquirrel_Mouse14 = JavaParsers.benchmarkSquirrel_Mouse_java14(input);

//        var timeSquirrel_Mouse8 = TestUtils.findMinTime(JavaParsers::benchmarkSquirrel_Mouse_java1p8, input);
//
//        System.out.println(input.length() + "\t" + timeParb1 * 1.0e-9 + "\t" + timeParb2 * 1.0e-9 + "\t"
//                + timeAntlr_java * 1.0e-9 + "\t" + timeAntlr_java8 * 1.0e-9 + "\t" + timeAntlr_java9 * 1.0e-9 + "\t"
//                + timeSquirrelParb * 1.0e-9 + "\t" + +timeSquirrel_Mouse8 * 1.0e-9);

        System.out.println("Finished");
    }
}
