package squirrelparser.node;

import java.util.Collections;
import java.util.List;

import squirrelparser.grammar.clause.Clause;
import squirrelparser.grammar.clause.nonterminal.First;
import squirrelparser.grammar.clause.nonterminal.OneOrMore;
import squirrelparser.grammar.clause.terminal.Terminal;
import squirrelparser.utils.TreePrinter;

/** A match (i.e. a parse tree node). */
public class Match {
    public final Clause clause;
    public final int pos;
    public final int len;
    public final List<Match> subClauseMatches;
    public final int firstMatchingSubClauseIdx;

    /** Used to return or memoize the notification that the clause did not match. */
    public static final Match NO_MATCH = new Match(null, -1, 0, 0, Collections.emptyList()) {
        @Override
        public boolean isBetterThan(Match other) {
            // NO_MATCH only beats there being no entry in the memo table
            return other == null;
        }

        @Override
        public String toString() {
            return "NO_MATCH";
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

    /** Find total length (in characters) of a list of subclause matches. */
    private static int totLen(List<Match> subClauseMatches) {
        var totLen = 0;
        for (int i = 0; i < subClauseMatches.size(); i++) {
            totLen += subClauseMatches.get(i).len;
        }
        return totLen;
    }

    /** A match with zero or more subclause matches. */
    public Match(Clause clause, int pos, List<Match> subClauseMatches) {
        this(clause, pos, totLen(subClauseMatches), 0, subClauseMatches);
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

    /** A match of a {@link Terminal}. */
    public Match(Terminal clause, int pos, int len) {
        this(clause, pos, len, 0, Collections.emptyList());
    }

    /** A match of zero length, with no subclause matches. */
    public Match(Clause clause, int pos) {
        this(clause, pos, 0, 0, Collections.emptyList());
    }

    /**
     * Returns true if this match is "better than" the other match, defined as having a lower first matching
     * subclause index (for {@link First} clauses), or longer subclause matches, or matching more times (for
     * {@link OneOrMore} clauses).
     */
    public boolean isBetterThan(Match other) {
        if (other == null || other == NO_MATCH) {
            return true;
        }
        if (this.clause.getClass() != other.clause.getClass()) {
            throw new IllegalArgumentException("Comparing matches of different clause type");
        }
        // Compare first matching subclause index (for First)
        if (this.firstMatchingSubClauseIdx < other.firstMatchingSubClauseIdx) {
            return true;
        }
        // Greedily compare subclause match lengths, left-to-right
        for (int i = 0, min = Math.min(this.subClauseMatches.size(), other.subClauseMatches.size()); i < min; i++) {
            var ti = this.subClauseMatches.get(i);
            var oi = other.subClauseMatches.get(i);
            if (ti.len > oi.len) {
                return true;
            }
        }
        // Compare number of subclause matches (for OneOrMore)
        if (this.subClauseMatches.size() > other.subClauseMatches.size()) {
            return true;
        }
        // Matches are equal
        return false;
    }

    /** Get the subsequence of the input matched by this {@link Match}. */
    public String getText(String input) {
        return input.substring(pos, pos + len);
    }

    /** Render the parse tree into ASCII art form. */
    public String toStringWholeTree(String input) {
        StringBuilder buf = new StringBuilder();
        TreePrinter.renderTreeView(this, clause.astNodeLabel, input, "", true, buf);
        return buf.toString();
    }

    @Override
    public String toString() {
        return (clause.rule == null ? "" : clause.rule.ruleName + " <- ") + clause + " : " + pos + "+" + len;
    }
}