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
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import squirrelparser.grammar.Grammar;
import squirrelparser.grammar.clause.Clause;
import squirrelparser.node.ASTNode;
import squirrelparser.node.Match;

/** The parser (holds the memo table and other parsing information). */
public class Parser {
    /** The grammar. */
    public final Grammar grammar;

    /** The input to parse. */
    public String input;

    // -------------------------------------------------------------------------------------------------------------

    /** A sparse memo table uses less memory, but the parser runs more slowly. */
    public static boolean USE_SPARSE_MEMO_TABLE = false;

    /** The memo table as a (dense) array. */
    public MemoEntry[][] memoTableAsArray;

    /** The memo table as a (sparse) map. */
    public Map<RulePos, MemoEntry> memoTableAsMap;

    /** Reuse {@link RulePos} instances. */
    private List<RulePos> rulePosRecycler;

    // -------------------------------------------------------------------------------------------------------------

    /** The number of left recursive cycles that have been expanded at each input position. */
    public int[] cycleDepthForPos;

    // -------------------------------------------------------------------------------------------------------------

    /** Current recursion depth (used when DEBUG == true). */
    public int recursionDepth;

    /** If true, print debug info while parsing. */
    public static boolean DEBUG = false;

    // -------------------------------------------------------------------------------------------------------------

    /** Construct a parser. */
    public Parser(Grammar grammar) {
        this.grammar = grammar;
    }

    /** Get all memo table entries. */
    public Collection<MemoEntry> getMemoEntries() {
        if (USE_SPARSE_MEMO_TABLE) {
            return memoTableAsMap.values();
        } else {
            var values = new ArrayList<MemoEntry>();
            for (int i = 0; i < grammar.rules.size(); i++) {
                for (int j = 0; j <= input.length(); j++) {
                    var value = memoTableAsArray[i][j];
                    if (value != null) {
                        values.add(value);
                    }
                }
            }
            return values;
        }
    }

    /** Parse a rule while handling left recursion. */
    public Match match(Clause rule, int pos) {
        // Get the existing memo entry for this rule and position, if there is one, otherwise add
        // a new blank memo entry to the memo table for this rule and position.
        var memoEntry = (MemoEntry) null;
        var rulePos = (RulePos) null;
        if (USE_SPARSE_MEMO_TABLE) {
            // Use a sparse map for the memo table. (Recycling RulePos instances increases speed by 10%.)
            rulePos = rulePosRecycler.isEmpty() ? new RulePos(rule, pos)
                    : rulePosRecycler.remove(rulePosRecycler.size() - 1).set(rule, pos);
            memoEntry = memoTableAsMap.computeIfAbsent(rulePos, ignoreKey -> new MemoEntry());
        } else {
            // Using an array rather than a map for memo table increases speed by up to 2x, but takes more memory.
            memoEntry = memoTableAsArray[rule.ruleIdx][pos];
            if (memoEntry == null) {
                memoEntry = new MemoEntry();
                memoTableAsArray[rule.ruleIdx][pos] = memoEntry;
            }
        }

        // Match this rule at this position, and store or update the match result in the memo entry
        recursionDepth++;
        var match = memoEntry.match(this, rule, pos);
        --recursionDepth;

        // Recycle memory for reuse
        if (USE_SPARSE_MEMO_TABLE) {
            rulePosRecycler.add(rulePos);
        }

        // Return the match
        return match;
    }

    /** Start parsing from the top rule at the beginning of the input. */
    public Match parse(String input) {
        this.input = input;
        cycleDepthForPos = new int[input.length() + 1];
        if (USE_SPARSE_MEMO_TABLE) {
            memoTableAsMap = new HashMap<>();
            rulePosRecycler = new ArrayList<>();
        } else {
            memoTableAsArray = new MemoEntry[grammar.rules.size()][input.length() + 1];
        }

        // Start recursive descent parsing
        var topMatch = match(grammar.topRule, 0);

        if (DEBUG) {
            var totCycleDepth = 0;
            for (var depth : cycleDepthForPos) {
                totCycleDepth += depth;
            }
            System.out.println("Total left recursive cycle expansions: " + totCycleDepth);
        }

        if (USE_SPARSE_MEMO_TABLE) {
            rulePosRecycler = null;
        }
        return topMatch;
    }

    /**
     * Start parsing from the top rule at the beginning of the input. Parses directly to AST form, rather than
     * returning the raw parse tree.
     */
    public ASTNode parseToAST(String input) {
        var topMatch = parse(input);
        if (topMatch.len < input.length()) {
            // TODO: better error reporting
            throw new IllegalArgumentException("Did not parse all of input");
        }
        return new ASTNode(topMatch, input);
    }
}
