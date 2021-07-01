package eqn;

import java.io.IOException;

public class BenchmarkEquationsLeftRec {
    public static void main(String[] args) throws IOException {
        var maxDepth = 10;
        var totSquirrelLeftRec = 0.0;
        var totMouseLeftRec = 0.0;
        {
            System.out.println("\nSquirrel Left Rec: ======================");
            var eq = new EquationGenerator();
            for (int depth = 0; depth < maxDepth; depth++) {
                for (int i = 0; i < 100; i++) {
                    var input = eq.generateEquation(depth);
                    var time = BenchmarkEquations.benchmarkSquirrelLeftRec(input);
                    System.out.println(depth + "\t" + input.length() + "\t" + time * 1.0e-9);
                    totSquirrelLeftRec += time;
                }
            }
        }
        {
            System.out.println("\nMouse Left Rec: ======================");
            var eq = new EquationGenerator();
            for (int depth = 0; depth < maxDepth; depth++) {
                for (int i = 0; i < 100; i++) {
                    var input = eq.generateEquation(depth);
                    var time = BenchmarkEquations.benchmarkMouse23LeftRec(input);
                    System.out.println(depth + "\t" + input.length() + "\t" + time * 1.0e-9);
                    totMouseLeftRec += time;
                }
            }
        }
        System.out.println("\nTOT:\n\n" + totSquirrelLeftRec * 1.0e-9 + "\t" + totMouseLeftRec * 1.0e-9);
    }
}
