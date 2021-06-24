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

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
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
    public Map<RulePos, MemoEntry> memoTable;

    /** If true, print debug info while parsing. */
    public static boolean DEBUG = false;

    /** Current recursion depth (used when DEBUG == true). */
    public int recursionDepth;

    /** Reuse {@link RulePos} instances. */
    private List<RulePos> rulePosRecycler;

    /** Construct a parser. */
    public Parser(Grammar grammar) {
        this.grammar = grammar;
    }

    /** Allocate a new {@link RulePos}. */
    private RulePos newRulePos(Clause rule, int pos) {
        //        return new RulePos(rule, pos);
        return rulePosRecycler.isEmpty() ? new RulePos(rule, pos)
                : rulePosRecycler.remove(rulePosRecycler.size() - 1).set(rule, pos);
    }

    /** Recycle a {@link RulePos}. Increases parsing speed by ~10%. */
    private void recycle(RulePos rulePos) {
        rulePosRecycler.add(rulePos);
    }

    /** Parse a rule while handling left recursion. */
    public Match match(Clause rule, int pos, int parentRuleStart) {
        recursionDepth++;
        // Get the existing memo entry for this rule and position, if there is one, otherwise add
        // a new blank memo entry to the memo table for this rule and position.
        var rulePos = newRulePos(rule, pos);
        var memoEntry = memoTable.computeIfAbsent(rulePos, ignoreKey -> new MemoEntry());
        // Match this rule at this position, and store or update the match result in the memo entry
        var match = memoEntry.match(this, rule, pos, parentRuleStart);
        // Prep to exit recursion frame
        --recursionDepth;
        recycle(rulePos);
        // Return the match
        return match;
    }

    /** Start parsing from the top rule at the beginning of the input. */
    public Match parse(String input) {
        this.input = input;
        memoTable = new HashMap<>();
        rulePosRecycler = new ArrayList<>();
        var topMatch = match(grammar.topRule, 0, /* parentRuleStart = */ -1);
        rulePosRecycler = null;
        return topMatch;
    }
}
