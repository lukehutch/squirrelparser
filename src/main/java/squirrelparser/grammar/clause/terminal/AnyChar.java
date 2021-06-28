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

import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

/**
 * Matches any character.
 *
 * <p>
 * May be used as, for example: {@code
 * 
 * SkipToEOL <- (!'\n' _)+ '\n'?;
 * 
 * }
 */
public class AnyChar extends Terminal {
    public final char chr;
    public final boolean invert;

    public AnyChar(char chr, boolean invert) {
        this.chr = chr;
        this.invert = invert;
    }

    public AnyChar(char chr) {
        this(chr, false);
    }

    @Override
    public Match match(Parser parser, int pos) {
        if (pos < parser.input.length()) {
            return new Match(this, pos, 1);
        }
        return Match.MISMATCH;
    }

    @Override
    public String toString() {
        return labelClause("_");
    }
}