package com.squirrelparser.parser;

import static com.squirrelparser.parser.MatchResult.mismatch;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.clause.nonterminal.Ref;

/**
 * The squirrel parser with bounded error recovery.
 */
public final class Parser {
    private final Map<String, Clause> rules;
    private final Set<String> transparentRules;
    private final String topRuleName;
    private final String input;
    private final Map<Clause, Map<Integer, MemoEntry>> memoTable;
    private final int[] memoVersion;
    private boolean inRecoveryPhase = false;

    public Parser(Map<String, Clause> rules, String topRuleName, String input) {
        this.rules = new HashMap<>();
        this.transparentRules = new HashSet<>();
        this.topRuleName = topRuleName;
        this.input = input;
        this.memoTable = new HashMap<>();
        this.memoVersion = new int[input.length() + 1];

        // Process rules: strip '~' prefix indicating a transparent rule
        for (var entry : rules.entrySet()) {
            if (entry.getKey().startsWith("~")) {
                String ruleName = entry.getKey().substring(1);
                this.rules.put(ruleName, entry.getValue());
                transparentRules.add(ruleName);
            } else {
                this.rules.put(entry.getKey(), entry.getValue());
            }
        }
    }

    public Map<String, Clause> rules() { return rules; }
    public Set<String> transparentRules() { return transparentRules; }
    public String topRuleName() { return topRuleName; }
    public String input() { return input; }
    public int[] memoVersion() { return memoVersion; }
    public boolean inRecoveryPhase() { return inRecoveryPhase; }

    /**
     * Match a clause at a position, using memoization.
     */
    public MatchResult match(Clause clause, int pos, Clause bound) {
        if (pos > input.length()) {
            return mismatch();
        }

        // C5 (Ref Transparency): Don't memoize Ref independently
        if (clause instanceof Ref) {
            return clause.match(this, pos, bound);
        }

        @SuppressWarnings("unused")
        MemoEntry memoEntry = memoTable
            .computeIfAbsent(clause, k -> new HashMap<>())
            .computeIfAbsent(pos, k -> new MemoEntry());
        return memoEntry.match(this, clause, pos, bound);
    }

    public MatchResult match(Clause clause, int pos) {
        return match(clause, pos, null);
    }

    /**
     * Match a named rule at a position.
     */
    public MatchResult matchRule(String ruleName, int pos) {
        Clause clause = rules.get(ruleName);
        if (clause == null) {
            throw new IllegalArgumentException("Rule \"" + ruleName + "\" not found");
        }
        return match(clause, pos);
    }

    /**
     * Get the MemoEntry for a clause at a position (if it exists).
     */
    public MemoEntry getMemoEntry(Clause clause, int pos) {
        var clauseMap = memoTable.get(clause);
        return clauseMap != null ? clauseMap.get(pos) : null;
    }

    /**
     * Probe: Temporarily switch out of recovery mode to check if clause can match.
     */
    public MatchResult probe(Clause clause, int pos) {
        boolean savedPhase = inRecoveryPhase;
        inRecoveryPhase = false;
        MatchResult result = match(clause, pos);
        inRecoveryPhase = savedPhase;
        return result;
    }

    /**
     * Enable recovery mode (Phase 2).
     */
    public void enableRecovery() {
        inRecoveryPhase = true;
    }

    /**
     * Check if clause can match non-zero characters at position.
     */
    public boolean canMatchNonzeroAt(Clause clause, int pos) {
        MatchResult result = probe(clause, pos);
        return !result.isMismatch() && result.len() > 0;
    }

    /**
     * Parse input with two-phase error recovery.
     */
    public ParseResult parse() {
        // Phase 1: Discovery (try to parse without recovery from syntax errors)
        MatchResult result = matchRule(topRuleName, 0);
        boolean hasSyntaxErrors = result.isMismatch() || result.pos() != 0 || result.len() != input.length();
        if (hasSyntaxErrors) {
            // Phase 2: Attempt to recover from syntax errors
            enableRecovery();
            result = matchRule(topRuleName, 0);
        }

        return new ParseResult(
            input,
            !result.isMismatch() ? result : new SyntaxError(0, input.length()),
            topRuleName,
            transparentRules,
            hasSyntaxErrors,
            hasSyntaxErrors && result.len() < input.length()
                ? new SyntaxError(result.len(), input.length() - result.len())
                : null
        );
    }
}
