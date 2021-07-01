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
package squirrelparser.grammar.clause.nonterminal;

import java.util.ArrayList;

import squirrelparser.grammar.clause.Clause;
import squirrelparser.grammar.clause.ClauseWithOneSubClause;
import squirrelparser.node.Match;
import squirrelparser.parser.Parser;

/** Always matches, consuming as many subclause matches as possible, starting at the current position. */
public class ZeroOrMore extends ClauseWithOneSubClause {
    public ZeroOrMore(Clause subClause) {
        super("", "*", subClause);
    }

    @Override
    public Match match(Parser parser, int pos) {
        ArrayList<Match> subClauseMatches = null;
        var currPos = pos;
        while (true) {
            var subClauseMatch = subClause.match(parser, currPos);
            if (subClauseMatch == Match.MISMATCH) {
                break;
            }
            if (subClauseMatches == null) {
                subClauseMatches = new ArrayList<>();
            }
            subClauseMatches.add(subClauseMatch);
            currPos += subClauseMatch.len;
            // If subclauseMatch.len == 0, then to avoid an infinite loop, only match once.
            if (subClauseMatch.len == 0) {
                break;
            }
        }
        if (subClauseMatches != null) {
            subClauseMatches.trimToSize();
            return new Match(this, pos, currPos - pos, subClauseMatches);
        } else {
            // Zero-width match (always matches)
            return new Match(this, pos);
        }
    }
}
