package squirrel;

import java.io.IOException;

import javaparse.JavaParsers;
import javaparse.squirrel.SquirrelParboiledJavaGrammar;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

public class TestJavaParsing {

    public static long benchmarkSquirrel_Parboiled_java1p6(String input) throws IOException {
        var startTime = System.nanoTime();
        var parser = new Parser(SquirrelParboiledJavaGrammar.grammar, input);
        var match = parser.parse();

        //        // TODO: why do we get a zero-length match and not NO_MATCH when there's a diamond operator? 
        //        System.out.println(match.pos + "\t" + match.len + "\t" + input.length());

        if (match == Match.NO_MATCH) {
            System.out.println("Syntax error");
            return -1;
        }
        var elapsedTime = System.nanoTime() - startTime;
        return elapsedTime;
    }

    public static void main(String[] args) throws IOException {
        var input = "class X { List<String> xs = new ArrayList(); }";
        //var input = "classX{List<String>xs=newArrayList();}";

        var timeParb = JavaParsers.benchmarkParboiled_java(input);

        var timeSquirrelParb = benchmarkSquirrel_Parboiled_java1p6(input);

        System.out.println(timeParb + "\t" + timeSquirrelParb);
        
        System.out.println("Finished");
    }
}