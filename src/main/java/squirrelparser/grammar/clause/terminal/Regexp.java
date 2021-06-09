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

import java.util.regex.Pattern;

import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

/**
 * Matches if the regexp matches, starting at the current position. The length of the match is the number of
 * characters matched by the regexp.
 * 
 * <p>
 * This {@link Terminal} may be thought of as a sort of lexer or tokenizer, and may result in faster parsing with
 * lower memory requirements than if the token parsing is built using PEG rules. PEG rules may result in one
 * {@link Match} (and therefore one memo entry) per character of each token.
 */
public class Regexp extends Terminal {
    private final String regexp;
    private final Pattern pattern;

    public Regexp(String regexp) {
        this.regexp = regexp;
        this.pattern = Pattern.compile(regexp);
    }

    @Override
    public Match match(int pos, int rulePos, Parser parser) {
        var remainderOfInput = parser.input.subSequence(pos, parser.input.length());
        var matcher = pattern.matcher(remainderOfInput);
        if (matcher.lookingAt()) {
            return new Match(this, pos, matcher.end());
        } else {
            return Match.NO_MATCH;
        }
    }

    @Override
    public String toString() {
        return labelClause('`' + regexp + '`');
    }
}
