//
// This file is part of the squirrel parser reference implementation:
//
//     https://github.com/lukehutch/squirrelparser
//
// This software is provided under the MIT license:
//
// Copyright 2021 Luke A. D. Hutchison
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions
// of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
// TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//
package squirrelparser.grammar.clause.terminal;

import java.util.BitSet;

import squirrelparser.utils.StringUtils;

/** Matches a character or sequence of characters. */
public class CharSet extends Terminal {
    public final BitSet chars;
    public final boolean invert;

    public CharSet(BitSet chars, boolean invert) {
        if (chars.cardinality() == 0) {
            throw new IllegalArgumentException("Must provide at least one char in a CharSet");
        }
        this.chars = chars;
        this.invert = invert;
    }

    public CharSet(BitSet chars) {
        this(chars, false);
    }

    public CharSet(boolean invert, char... chars) {
        this.chars = new BitSet(128);
        for (char element : chars) {
            this.chars.set(element);
        }
        this.invert = invert;
    }

    public CharSet(char... chars) {
        this(false, chars);
    }

    @Override
    public int matchLen(String input, int pos) {
        if (pos < input.length()) {
            char c = input.charAt(pos);
            if ((!invert && chars.get(c)) || (invert && !chars.get(c))) {
                return 1;
            }
        }
        return -1;
    }

    @Override
    public String toString() {
        var buf = new StringBuilder();
        boolean isSingleChar = !invert && chars.cardinality() == 1;
        if (isSingleChar) {
            char c = (char) chars.nextSetBit(0);
            buf.append('\'');
            buf.append(StringUtils.escapeChar(c));
            buf.append('\'');
        } else {
            buf.append('[');
            if (invert) {
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
        return labelClause(buf.toString());
    }
}