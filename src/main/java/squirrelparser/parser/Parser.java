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
package squirrelparser.parser;

import java.util.HashMap;
import java.util.Map;

import squirrelparser.grammar.Grammar;
import squirrelparser.grammar.Rule;
import squirrelparser.node.Match;

/** The parser (holds the memo table and other parsing information). */
public class Parser {
    /** The grammar. */
    private Grammar grammar;

    /** The input to parse. */
    public final String input;

    /** The memo table. */
    public final Map<RuleAndPos, Match> memoTable = new HashMap<>();

    /**
     * A map allowing for fast lookup of the rules and positions of ancestral recursion frames, as well as for
     * looking up whether or not the current rule needs to iteratively continue to try to grow a left-recursive
     * match at the current position. There is one entry for each recursion frame in stack. The Boolean value
     * indicates whether or not a left-recursive cycle of the key's rule has been encountered yet in the grammar at
     * the key's position. A key is first put into the map with a false value, indicating that the key is on the
     * recursion path but a left-recursive cycle has not yet been encountered. If a left-recursive cycle is found
     * (i.e. a grammar cycle which revisits the same rule at the same position), then the value in the map is
     * switched from false to true, to notify the ancestral recursion frame that it needs to iteratively expand the
     * left recursion.
     */
    public final Map<RuleAndPos, Boolean> iterRuleAtPos = new HashMap<>();

    /**
     * A map indicating the position of the leftmost (highest ancestral) recursion frame for the current rule, i.e.
     * the position at which a rule must iteratively attempt to match a left-recursive grammar cycle, in order to
     * ensure left associativity of ambiguous grammars.
     */
    public final Map<Rule, Integer> leftRecIterPos = new HashMap<>();

    /** If true, print debug info. */
    public static final boolean DEBUG = false;

    /** If true, prefer left recursion for ambiguous rules like E <- E '+' E. */
    public static final boolean PREFER_LEFT_RECURSION = true;

    /** Construct a parser. */
    public Parser(Grammar grammar, String input) {
        this.grammar = grammar;
        this.input = input;
    }

    /** Start parsing from the top rule at the beginning of the input. */
    public Match parse() {
        return grammar.topRule.match(0, /* parentRulePos = */ -1, this);
    }
}
