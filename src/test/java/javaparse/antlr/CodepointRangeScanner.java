package javaparse.antlr;

import java.util.ArrayList;

class CodepointRangeScanner {
    static int UNICODE_RANGE = 0x10000;

    public static void main(String[] args) {
        boolean startCh[] = new boolean[UNICODE_RANGE];
        boolean partCh[] = new boolean[UNICODE_RANGE];

        for (int i = 0; i < UNICODE_RANGE; i++) {
            startCh[i] = Character.isJavaIdentifierStart(i);
            partCh[i] = (Character.isJavaIdentifierPart(i) && !startCh[i] && i > 0x20);
        }

        System.out.println("fragment IdentifierStart\n\t: " + printRanges(startCh));
        System.out.println("fragment IdentifierPart\n\t: IdentifierStart\n\t| " + printRanges(partCh));
    }

    static String printRanges(boolean[] a) {
        ArrayList<String> s = new ArrayList<String>();
        boolean last = false;
        int start = -1;
        for (int p = 0; p <= a.length; p++) {
            if (p == a.length && last == false) {
                // Do nothing
            } else if ((p == a.length || a[p] == false) && last == true) {
                s.add(printRange(start, p - 1));
                last = false;
            } else if (a[p] == true && last == false) {
                start = p;
                last = true;
            }
        }
        return String.join("\n\t| ", s) + "\n\t;\n";
    }

    static String printRange(int start, int end) {
        if (start >= end) {
            return String.format("[%s]", escapeCodepoint(start));
        } else {
            return String.format("[%s-%s]", escapeCodepoint(start), escapeCodepoint(end));
        }
    }

    static String escapeCodepoint(int cp) {
        if (cp < 0x10000)
            return String.format("\\u%04X", cp);
        else {
            int s1 = 0xD800 | (cp >> 10);
            int s2 = 0xDC00 | (cp & 0x3FF);
            return String.format("\\u%04X\\u%04X", s1, s2);
        }
    }
}