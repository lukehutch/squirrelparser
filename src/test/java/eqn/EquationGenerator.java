package eqn;

import java.util.Random;

public class EquationGenerator {

    private static Random rand = new Random(1);

    private static final int MAX_INT = 1000;

    // Precedence levels:
    //
    // 4: ( E )
    // 3: num
    // 2: -
    // 1: * /
    // 0: ? -

    private static void op(StringBuilder buf, int parentPrec, int depth) {
        int prec;
        if (depth <= 0) {
            prec = 3;
        } else {
            prec = rand.nextInt(3);
            if (prec == 3) {
                prec++;
            }
        }
        if (prec <= parentPrec) {
            buf.append('(');
        }
        switch (prec) {
        case 4:
            op(buf, prec, depth - 1);
            break;
        case 3:
            buf.append("" + rand.nextInt(MAX_INT));
            break;
        case 2:
            buf.append('-');
            op(buf, prec, depth - 1);
            break;
        case 1:
            op(buf, prec, depth - 1);
            buf.append(rand.nextBoolean() ? '*' : '/');
            op(buf, prec, depth - 1);
            break;
        case 0:
            op(buf, prec, depth - 1);
            buf.append(rand.nextBoolean() ? '+' : '-');
            op(buf, prec, depth - 1);
            break;
        }
        if (prec <= parentPrec) {
            buf.append(')');
        }
    }

    public static String generateEquation(int recursionDepth) {
        var buf = new StringBuilder();
        op(buf, 99, recursionDepth);
        return buf.toString();
    }

    public static void main(String[] args) {
        var eq = generateEquation(10);
        System.out.println(eq.length());
    }
}
