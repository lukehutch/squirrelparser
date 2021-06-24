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
package squirrelparser.utils;

import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

public class MemoUtils {
    /** Find the maximum end position of any match in the memo table. */
    public static int findMaxEndPos(Parser parser) {
        int maxEndPos = 0;
        for (var ent : parser.getMemoEntries()) {
            var match = ent.match;
            if (match != Match.MISMATCH) {
                maxEndPos = Math.max(maxEndPos, match.pos + match.len);
            }
        }
        return maxEndPos;
    }

    private static final int SYTAX_ERROR_CONTEXT_WINDOW_SIZE = 60;
    
    /** Display the syntax error position after the last successful match */
    public static void printSyntaxError(Parser parser) {
        var endPos = findMaxEndPos(parser);
        
        // Find line/col number in input corresponding to endPos
        int line = 0;
        int col = 0;
        for (int i = 0; i < endPos; i++) {
            char c = parser.input.charAt(i);
            if (c == '\n' || c == '\r') {
                line++;
                col = 0;
                if (c == '\r' && i < parser.input.length() - 1 && parser.input.charAt(i + 1) == '\n') {
                    i++;
                }
            } else {
                col++;
            }
        }

        System.out
                .println("Syntax error at line " + (line + 1) + " col " + (col + 1) + " pos " + (endPos + 1) + ":");
        int charsBefore = Math.min(SYTAX_ERROR_CONTEXT_WINDOW_SIZE, endPos);
        int charsAfter = Math.min(SYTAX_ERROR_CONTEXT_WINDOW_SIZE, parser.input.length() - endPos);
        var chrs = parser.input.substring(endPos - charsBefore, endPos + charsAfter);
        System.out.println(StringUtils.replaceNonASCII(chrs));
        for (int i = 0; i < charsBefore; i++) {
            System.out.print(' ');
        }
        System.out.println('^');
    }

}
