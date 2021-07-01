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

import squirrelparser.utils.StringUtils;

/** Matches a character or sequence of characters. */
public class CharRange extends Terminal {
    public final char minChar;
    public final char maxChar;
    public final boolean invert;

    public CharRange(char minChar, char maxChar, boolean inverted) {
        this.minChar = minChar;
        this.maxChar = maxChar;
        this.invert = inverted;
    }

    public CharRange(char minChar, char maxChar) {
        this(minChar, maxChar, false);
    }

    @Override
    public int matchLen(String input, int pos) {
        if (pos < input.length()) {
            char c = input.charAt(pos);
            if ((!invert && c >= minChar && c <= maxChar) || (invert && (c < minChar || c > maxChar))) {
                return 1;
            }
        }
        return -1;
    }

    @Override
    public String toString() {
        return labelClause("[" + (invert ? "^" : "") + StringUtils.escapeCharRangeChar(minChar) + "-"
                + StringUtils.escapeCharRangeChar(maxChar) + "]");
    }
}