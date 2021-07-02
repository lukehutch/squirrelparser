package json;

import java.util.Random;

public class JSONGenerator {

    private Random rand = new Random(1);

    private void num(StringBuilder buf) {
        buf.append("" + rand.nextDouble() * rand.nextLong());
    }

    private void val(StringBuilder buf) {
        var r = rand.nextInt(3);
        buf.append(r == 0 ? "true" : r == 1 ? "false" : "null");
    }

    private void str(StringBuilder buf) {
        buf.append('"');
        var n = rand.nextInt(8);
        for (int i = 0; i < n; i++) {
            char c = (char) (rand.nextInt(127 - 32) + 32);
            if (c == '\\') {
                buf.append("\\\\");
            } else if (c == '"') {
                buf.append("\\\"");
            } else {
                buf.append(c);
            }
        }
        buf.append('"');
    }

    private void obj(StringBuilder buf, int depth, int maxDepth) {
        buf.append('{');
        int n = rand.nextInt(15) + 1;
        for (int i = 0; i < n; i++) {
            str(buf);
            buf.append(':');
            json(buf, depth + 1, maxDepth);
            if (i < n - 1) {
                buf.append(',');
            }
        }
        buf.append('}');
    }

    private void arr(StringBuilder buf, int depth, int maxDepth) {
        buf.append('[');
        int n = rand.nextInt(15) + 1;
        for (int i = 0; i < n; i++) {
            json(buf, depth + 1, maxDepth);
            if (i < n - 1) {
                buf.append(',');
            }
        }
        buf.append(']');
    }

    private void json(StringBuilder buf, int depth, int maxDepth) {
        var r = 0;
        if (depth < maxDepth) {
            r = rand.nextInt(5);
        }
        switch (r) {
        case 0:
            val(buf);
            break;
        case 1:
            str(buf);
            break;
        case 2:
            num(buf);
            break;
        case 3:
            arr(buf, depth, maxDepth);
            break;
        case 4:
            obj(buf, depth, maxDepth);
            break;
        }

    }

    public String generateJSON(int maxDepth) {
        var buf = new StringBuilder();
        obj(buf, 0, maxDepth);
        return buf.toString();
    }

    //    public static void main(String[] args) {
    //        var eq = new JSONGenerator().generateJSON(8);
    //        System.out.println(eq.length());
    //    }
}
