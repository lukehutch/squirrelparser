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
import squirrelparser.grammar.clause.Clause;
import squirrelparser.node.Match;

/** The parser (holds the memo table and other parsing information). */
public class Parser {
    /** The grammar. */
    public final Grammar grammar;

    /** The input to parse. */
    public String input;

    /** The memo table. */
    public final Map<RulePos, MemoEntry> memoTable = new HashMap<>();

    /** If true, print debug info while parsing. */
    public static final boolean DEBUG = true;
    
    /** Current recursion depth (used when DEBUG == true). */
    public int recursionDepth;
    
    /** Construct a */
    public Parser(Grammar grammar) {
        this.grammar = grammar;
    }

    /** Parse a rule while handling left recursion. */
    public Match match(Clause rule, int pos, int parentRuleStart) {
        recursionDepth++;
        // Get the existing memo entry for this rule and position, if there is one, otherwise add
        // a new blank memo entry to the memo table for this rule and position.
        var memoEntry = memoTable.computeIfAbsent(new RulePos(rule, pos), ignoreKey -> new MemoEntry());
        // Match this rule at this position, and store or update the match result in the memo entry
        var match = memoEntry.match(this, rule, pos, parentRuleStart);
        // Return the match
        --recursionDepth;
        return match;
    }

    /** Start parsing from the top rule at the beginning of the input. */
    public Match parse(String input) {
        this.input = input;
        memoTable.clear();
        return match(grammar.topRule, 0, /* parentRuleStart = */ -1);
    }
}
