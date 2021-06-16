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

    /** One entry for each recursion frame in stack. Value indicates whether key is a cycle head or not. */
    public final Map<RuleAndPos, Boolean> cycleStart = new HashMap<>();

    public final Map<Rule, Integer> loopingPosition = new HashMap<>();
    
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
