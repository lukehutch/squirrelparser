package squirrelparser.grammar.clause.terminal;

import java.util.BitSet;

import squirrelparser.node.Match;
import squirrelparser.parser.Parser;
import squirrelparser.utils.StringUtils;

/** Matches a character or sequence of characters. */
public class CharSet extends Terminal {
    private BitSet chars;
    private BitSet invertedChars;

    public CharSet(char... chars) {
        super();
        this.chars = new BitSet(128);
        for (int i = 0; i < chars.length; i++) {
            this.chars.set(chars[i]);
        }
    }

    public CharSet(CharSet... charSets) {
        super();
        if (charSets.length == 0) {
            throw new IllegalArgumentException("Must provide at least one CharSet");
        }
        this.chars = new BitSet(128);
        for (CharSet charSet : charSets) {
            if (charSet.chars != null) {
                for (int i = charSet.chars.nextSetBit(0); i >= 0; i = charSet.chars.nextSetBit(i + 1)) {
                    this.chars.set(i);
                }
            }
            if (charSet.invertedChars != null) {
                if (this.invertedChars == null) {
                    this.invertedChars = new BitSet(128);
                }
                for (int i = charSet.invertedChars.nextSetBit(0); i >= 0; i = charSet.invertedChars
                        .nextSetBit(i + 1)) {
                    this.invertedChars.set(i);
                }
            }
        }
    }

    public CharSet(BitSet chars) {
        super();
        if (chars.cardinality() == 0) {
            throw new IllegalArgumentException("Must provide at least one char in a CharSet");
        }
        this.chars = chars;
    }

    /** Invert in-place, and return this. */
    public CharSet invert() {
        var tmp = chars;
        chars = invertedChars;
        invertedChars = tmp;
        return this;
    }

    @Override
    public Match match(int pos, int rulePos, Parser parser) {
        if (pos < parser.input.length()) {
            char c = parser.input.charAt(pos);
            if ((chars != null && chars.get(c)) || (invertedChars != null && !invertedChars.get(c))) {
                return new Match(this, pos, 1);
            }
        }
        return Match.NO_MATCH;
    }

    private static void toString(BitSet chars, int cardinality, boolean inverted, StringBuilder buf) {
        boolean isSingleChar = !inverted && cardinality == 1;
        if (isSingleChar) {
            char c = (char) chars.nextSetBit(0);
            buf.append('\'');
            buf.append(StringUtils.escapeChar(c));
            buf.append('\'');
        } else {
            buf.append('[');
            if (inverted) {
                buf.append('^');
            }
            for (int i = chars.nextSetBit(0); i >= 0; i = chars.nextSetBit(i + 1)) {
                buf.append(StringUtils.escapeCharRangeChar((char) i));
                if (i < chars.size() - 1 && chars.get(i + 1)) {
                    // Contiguous char range
                    int end = i + 2;
                    while (end < chars.size() && chars.get(end)) {
                        end++;
                    }
                    int numCharsSpanned = end - i;
                    if (numCharsSpanned > 2) {
                        buf.append('-');
                    }
                    buf.append(StringUtils.escapeCharRangeChar((char) (end - 1)));
                    i = end - 1;
                }
            }
            buf.append(']');
        }
    }

    @Override
    public String toString() {
        var buf = new StringBuilder();
        var charsCardinality = chars == null ? 0 : chars.cardinality();
        var invertedCharsCardinality = invertedChars == null ? 0 : invertedChars.cardinality();
        var invertedAndNot = charsCardinality > 0 && invertedCharsCardinality > 0;
        if (invertedAndNot) {
            buf.append('(');
        }
        if (charsCardinality > 0) {
            toString(chars, charsCardinality, false, buf);
        }
        if (invertedAndNot) {
            buf.append(" | ");
        }
        if (invertedCharsCardinality > 0) {
            toString(invertedChars, invertedCharsCardinality, true, buf);
        }
        if (invertedAndNot) {
            buf.append(')');
        }
        return labelClause(buf.toString());
    }
}