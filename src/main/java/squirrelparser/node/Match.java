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
package squirrelparser.node;

import java.util.Collections;
import java.util.List;

import squirrelparser.grammar.clause.Clause;
import squirrelparser.grammar.clause.nonterminal.First;
import squirrelparser.grammar.clause.nonterminal.Longest;
import squirrelparser.grammar.clause.terminal.Terminal;
import squirrelparser.utils.StringUtils;
import squirrelparser.utils.TreePrinter;

/** A match (i.e. a parse tree node). */
public class Match {
    public final Clause clause;
    public final int pos;
    public final int len;
    public final List<Match> subClauseMatches;

    // This is no only used for printing debug info via toString()
    private final int firstMatchingSubClauseIdx;

    /** Used to return or memoize the notification that the clause did not match. */
    public static final Match MISMATCH = new Match(null, -1, -1, 0, Collections.emptyList()) {
        @Override
        public String toString(String input) {
            return toString();
        }

        @Override
        public String toString() {
            return "MISMATCH";
        }
    };

    /** A match of a clause with a specific AST node label. */
    private Match(Clause clause, int pos, int len, int firstMatchingSubClauseIdx, List<Match> subClauseMatches) {
        this.clause = clause;
        this.pos = pos;
        this.len = len;
        this.firstMatchingSubClauseIdx = firstMatchingSubClauseIdx;
        this.subClauseMatches = subClauseMatches;
    }

    /** A match with zero or more subclause matches. */
    public Match(Clause clause, int pos, int len, List<Match> subClauseMatches) {
        this(clause, pos, len, 0, subClauseMatches);
    }

    /** A match with a single subclause match. */
    public Match(Clause clause, Match subClauseMatch) {
        this(clause, subClauseMatch.pos, subClauseMatch.len, 0, Collections.singletonList(subClauseMatch));
    }

    /** A match of a {@link First} clause, with one subclause match. */
    public Match(First clause, int matchingSubClauseIdx, Match subClauseMatch) {
        this(clause, subClauseMatch.pos, subClauseMatch.len, matchingSubClauseIdx,
                Collections.singletonList(subClauseMatch));
    }

    /** A match of a {@link Longest} clause, with one subclause match. */
    public Match(Longest clause, int matchingSubClauseIdx, Match subClauseMatch) {
        this(clause, subClauseMatch.pos, subClauseMatch.len, matchingSubClauseIdx,
                Collections.singletonList(subClauseMatch));
    }

    /** A match of a {@link Terminal}. */
    public Match(Clause clause, int pos, int len) {
        this(clause, pos, len, 0, Collections.emptyList());
    }

    /** A match of zero length, with no subclause matches. */
    public Match(Clause clause, int pos) {
        this(clause, pos, 0, 0, Collections.emptyList());
    }

    /** Convert the parse tree to an AST. */
    public ASTNode toAST(String input) {
        return new ASTNode(this, input);
    }

    /** Get the subsequence of the input matched by this {@link Match}. */
    public String getText(String input) {
        return input.substring(pos, pos + len);
    }

    /** Render the parse tree into ASCII art form. */
    public String toStringWholeTree(String input) {
        if (this == Match.MISMATCH) {
            return "MISMATCH";
        } else {
            StringBuilder buf = new StringBuilder();
            TreePrinter.renderTreeView(this, clause.astNodeLabel, input, "", true, buf);
            return buf.toString();
        }
    }

    public String toString(String input) {
        return toString() + "[" + StringUtils.replaceNonASCII(getText(input)) + "]";
    }

    @Override
    public String toString() {
        return clause + " : " + pos + "+" + len
                + (clause instanceof First ? " (first matching subclause index: " + firstMatchingSubClauseIdx + ")"
                        : "");
    }
}