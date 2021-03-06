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

/**
 * Match a run of zero or more whitespace characters, defined by {@link Character#isWhitespace()}. (Always matches,
 * even if the character at the current position is not a whitespace character.)
 */
public class Whitespace extends Terminal {
    public static final String WS_DISPLAY_STR = "<WS>";

    public Whitespace() {
    }

    @Override
    public int matchLen(String input, int pos) {
        int currPos = pos;
        while (currPos < input.length()) {
            if (Character.isWhitespace(input.charAt(currPos))) {
                currPos++;
            } else {
                break;
            }
        }
        // Matches zero or more whitespace characters (always matches)
        return currPos - pos;
    }

    @Override
    public String toString() {
        return labelClause(WS_DISPLAY_STR);
    }
}
