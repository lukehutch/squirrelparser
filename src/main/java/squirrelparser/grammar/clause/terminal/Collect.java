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

import java.util.HashSet;
import java.util.Set;

import squirrelparser.grammar.clause.Clause;
import squirrelparser.grammar.clause.ClauseWithMultipleSubClauses;
import squirrelparser.grammar.clause.ClauseWithOneSubClause;
import squirrelparser.grammar.clause.SubClauseVisitor;
import squirrelparser.grammar.clause.nonterminal.RuleRef;
import squirrelparser.node.Match;

/**
 * Collect a tree of clauses together into a single terminal clause matcher. Allocates only a single {@link Match}
 * node if the whole tree of clauses matches, to reduce the number of memory allocations and the size of the parse
 * tree. There cannot be any cycles in the grammar graph starting from the clause that is passed into the
 * constructor.
 */
public class Collect extends Terminal {
    private Clause origClauseTree;

    /**
     * We build a tree out of "terminals" that are technically non-terminals in the tree of these clauses, but that
     * contribute towards a single collected terminal match.
     */
    private Terminal collectClauseTree;

    public Collect(Clause terminalClauseTree) {
        origClauseTree = terminalClauseTree;
    }

    @Override
    protected void visitSubclauses(SubClauseVisitor visitor) {
        origClauseTree = origClauseTree.visit(visitor);
    }

    /** Called after grammar has been created and all {@link RuleRef} references have been looked up. */
    public void convert() {
        collectClauseTree = convert(origClauseTree, new HashSet<Clause>());
    }

    @Override
    public int matchLen(String input, int pos) {
        return collectClauseTree.matchLen(input, pos);
    }

    @Override
    public String toString() {
        return labelClause(origClauseTree.toString());
    }
    
    @Override
    public String toJavaSource() {
        return origClauseTree.toJavaSource();
    }

    // -------------------------------------------------------------------------------------------------------------
    // Replicate the logic of the nonterminal clauses, but return only the match length, rather than allocating
    // a Match object. This is done here in this clause rather than in each of the nonterminal clauses to
    // simplify the code in the regular (non-collecting) case.

    private Terminal[] convertSubclauses(ClauseWithMultipleSubClauses clause, Set<Clause> visited) {
        var convertedTerminals = new Terminal[clause.subClauses.length];
        for (int i = 0; i < clause.subClauses.length; i++) {
            convertedTerminals[i] = convert(clause.subClauses[i], visited);
        }
        return convertedTerminals;
    }

    /**
     * Replicate the logic of a tree of {@link Clause} nodes in a tree of {@link CollectClause} nodes, but only
     * match lengths and don't allocate {@link Match} objects.
     */
    private Terminal convert(Clause clause, Set<Clause> visited) {
        if (!visited.add(clause)) {
            // TODO: improve error reporting
            throw new IllegalArgumentException("Cannot collect a clause graph that contains a cycle: " + clause);
        }
        try {
            if (clause instanceof Terminal) {
                return (Terminal) clause;
            }
            switch (clause.getClass().getSimpleName()) {
            case "First": {
                return new Terminal() {
                    final Terminal[] subClauses = convertSubclauses((ClauseWithMultipleSubClauses) clause, visited);

                    @Override
                    public int matchLen(String input, int pos) {
                        for (Terminal element : subClauses) {
                            var subClauseMatchLen = element.matchLen(input, pos);
                            if (subClauseMatchLen != -1) {
                                return subClauseMatchLen;
                            }
                        }
                        // No subclauses matched
                        return -1;
                    }
                };
            }
            case "FollowedBy": {
                return new Terminal() {
                    final Terminal subClause = convert(((ClauseWithOneSubClause) clause).subClause, visited);

                    @Override
                    public int matchLen(String input, int pos) {
                        return subClause.matchLen(input, pos) == -1 ? -1 : 0;
                    }
                };
            }
            case "Longest": {
                return new Terminal() {
                    final Terminal[] subClauses = convertSubclauses((ClauseWithMultipleSubClauses) clause, visited);

                    @Override
                    public int matchLen(String input, int pos) {
                        var longestMatchLen = -1;
                        for (Terminal element : subClauses) {
                            var subClauseMatchLen = element.matchLen(input, pos);
                            if (subClauseMatchLen != -1 && subClauseMatchLen > longestMatchLen) {
                                longestMatchLen = subClauseMatchLen;
                            }
                        }
                        return longestMatchLen;
                    }
                };
            }
            case "NotFollowedBy": {
                return new Terminal() {
                    final Terminal subClause = convert(((ClauseWithOneSubClause) clause).subClause, visited);

                    @Override
                    public int matchLen(String input, int pos) {
                        return subClause.matchLen(input, pos) == -1 ? 0 : -1;
                    }
                };
            }
            case "OneOrMore": {
                return new Terminal() {
                    final Terminal subClause = convert(((ClauseWithOneSubClause) clause).subClause, visited);

                    @Override
                    public int matchLen(String input, int pos) {
                        var numMatches = 0;
                        var currPos = pos;
                        while (true) {
                            var subClauseMatchLen = subClause.matchLen(input, currPos);
                            if (subClauseMatchLen == -1) {
                                break;
                            }
                            numMatches++;
                            currPos += subClauseMatchLen;
                            // If subclauseMatchLen == 0, then to avoid an infinite loop, only match once.
                            if (subClauseMatchLen == 0) {
                                break;
                            }
                        }
                        if (numMatches > 0) {
                            return currPos - pos;
                        } else {
                            return -1;
                        }
                    }
                };
            }
            case "Optional": {
                return new Terminal() {
                    final Terminal subClause = convert(((ClauseWithOneSubClause) clause).subClause, visited);

                    @Override
                    public int matchLen(String input, int pos) {
                        var subClauseMatchLen = subClause.matchLen(input, pos);
                        if (subClauseMatchLen != -1) {
                            return subClauseMatchLen;
                        } else {
                            // Zero-width match (always matches)
                            return 0;
                        }
                    }
                };
            }
            case "RuleRef": {
                return convert(((RuleRef) clause).refdRule, visited);
            }
            case "Seq": {
                return new Terminal() {
                    final Terminal[] subClauses = convertSubclauses((ClauseWithMultipleSubClauses) clause, visited);

                    @Override
                    public int matchLen(String input, int pos) {
                        var currPos = pos;
                        for (Terminal element : subClauses) {
                            var subClauseMatchLen = element.matchLen(input, currPos);
                            if (subClauseMatchLen == -1) {
                                return -1;
                            }
                            currPos += subClauseMatchLen;
                        }
                        return currPos - pos;
                    }
                };
            }
            case "ZeroOrMore": {
                return new Terminal() {
                    final Terminal subClause = convert(((ClauseWithOneSubClause) clause).subClause, visited);

                    @Override
                    public int matchLen(String input, int pos) {
                        var currPos = pos;
                        while (true) {
                            var subClauseMatchLen = subClause.matchLen(input, currPos);
                            if (subClauseMatchLen == -1) {
                                break;
                            }
                            currPos += subClauseMatchLen;
                            // If subclauseMatchLen == 0, then to avoid an infinite loop, only match once.
                            if (subClauseMatchLen == 0) {
                                break;
                            }
                        }
                        return currPos - pos;
                    }
                };
            }
            default:
                // TODO: better error reporting
                throw new IllegalArgumentException(
                        "Don't know how to collect from clause type " + clause.getClass().getSimpleName());
            }
        } finally {
            visited.remove(clause);
        }
    }
}