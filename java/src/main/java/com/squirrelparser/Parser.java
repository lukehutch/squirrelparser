package com.squirrelparser;

import java.util.HashMap;
import java.util.Map;

/**
 * Main parser class with packrat memoization and left-recursion handling.
 */
public class Parser {
    private final Map<String, Clause> rules;
    private final String input;
    private final Map<Clause, Map<Integer, MemoEntry>> memoTable;
    private final int[] memoVersion;
    private boolean inRecoveryPhase = false;

    public Parser(Map<String, Clause> rules, String input) {
        this.rules = rules;
        this.input = input;
        this.memoTable = new HashMap<>();
        this.memoVersion = new int[input.length() + 1];
    }

    public String input() {
        return input;
    }

    public Map<String, Clause> rules() {
        return rules;
    }

    public boolean inRecoveryPhase() {
        return inRecoveryPhase;
    }

    int getMemoVersion(int pos) {
        return memoVersion[pos];
    }

    void incrementMemoVersion(int pos) {
        memoVersion[pos]++;
    }

    /**
     * Match a clause at a position with memoization.
     */
    public MatchResult match(Clause clause, int pos, Clause bound) {
        // Check position bounds
        if (pos > input.length()) {
            return Mismatch.INSTANCE;
        }

        // C5 (Ref Transparency): Don't memoize Ref independently
        if (clause instanceof Combinators.Ref) {
            return clause.match(this, pos, bound);
        }

        var posMap = memoTable.computeIfAbsent(clause, k -> new HashMap<>());
        var entry = posMap.computeIfAbsent(pos, p -> new MemoEntry());

        return entry.match(this, clause, pos, bound);
    }

    /**
     * Probe: match in discovery phase (no recovery).
     */
    public MatchResult probe(Clause clause, int pos) {
        boolean wasInRecovery = inRecoveryPhase;
        inRecoveryPhase = false;
        MatchResult result = match(clause, pos, null);
        inRecoveryPhase = wasInRecovery;
        return result;
    }

    /**
     * Check if clause can match non-zero characters at position.
     */
    public boolean canMatchNonzeroAt(Clause clause, int pos) {
        MatchResult result = probe(clause, pos);
        return !result.isMismatch() && result.len() > 0;
    }

    /**
     * Parse result containing both the match result and whether recovery was used.
     */
    public record ParseResult(MatchResult result, boolean usedRecovery) {
    }

    /**
     * Parse input with the top rule, using two-phase error recovery. Returns a ParseResult containing the result
     * and whether recovery was used.
     */
    ParseResult parseWithRecovery(String topRule) {
        Clause rule = rules.get(topRule);
        if (rule == null) {
            throw new IllegalArgumentException("Rule not found: " + topRule);
        }

        // Phase 1: Discovery (no recovery)
        inRecoveryPhase = false;
        MatchResult result = match(rule, 0, null);

        if (!result.isMismatch() && result.len() == input.length()) {
            return new ParseResult(result, false);
        }

        // Phase 2: Recovery
        inRecoveryPhase = true;
        result = match(rule, 0, null);

        if (!result.isMismatch() && result.len() == input.length()) {
            return new ParseResult(result, true);
        }

        return new ParseResult(null, true);
    }

    /**
     * Convenience method to parse with a clause directly.
     */
    ParseResult parseWithRecovery(Clause topRule) {
        // Phase 1: Discovery (no recovery)
        inRecoveryPhase = false;
        MatchResult result = match(topRule, 0, null);

        if (!result.isMismatch() && result.len() == input.length()) {
            return new ParseResult(result, false);
        }

        // Phase 2: Recovery
        inRecoveryPhase = true;
        result = match(topRule, 0, null);

        if (!result.isMismatch() && result.len() == input.length()) {
            return new ParseResult(result, true);
        }

        return new ParseResult(null, true);
    }

    /**
     * Ensure result spans entire input (parse tree spanning invariant).
     * - Total failure: return SyntaxError spanning all input
     * - Partial match: wrap with trailing SyntaxError
     * - Complete match: return as-is
     */
    private MatchResult ensureSpansInput(MatchResult result) {
        if (result.isMismatch()) {
            // Total failure: entire input is an error
            return new SyntaxError(0, input.length(), input);
        }

        if (result.len() == input.length()) {
            // Already spans entire input
            return result;
        }

        // Partial match: wrap with trailing SyntaxError
        SyntaxError trailing = new SyntaxError(
            result.len(),
            input.length() - result.len(),
            input.substring(result.len())
        );

        // Create a wrapper Match that includes the original result and trailing error
        var children = java.util.Arrays.asList(result, trailing);
        return new Match(null, children, false);
    }

    /**
     * Parse input with the top rule, using two-phase error recovery.
     * Returns a MatchResult spanning entire input (never null).
     * For total failures, returns a SyntaxError spanning all input.
     */
    public MatchResult parse(String topRule) {
        ParseResult pr = parseWithRecovery(topRule);
        MatchResult result = pr.result() != null ? pr.result() : Mismatch.INSTANCE;
        return ensureSpansInput(result);
    }

    /**
     * Parse with a clause directly. Returns the MatchResult directly, or Mismatch if parsing failed.
     */
    public MatchResult parse(Clause topRule) {
        ParseResult pr = parseWithRecovery(topRule);
        return pr.result() != null ? pr.result() : Mismatch.INSTANCE;
    }

    /**
     * Parse input and return an AST. Wraps combinator results in a synthetic rule node.
     */
    public ASTNode parseToAST(String topRule) {
        ParseResult pr = parseWithRecovery(topRule);
        if (pr.result() == null || pr.result().isMismatch()) {
            return null;
        }

        ASTNode ast = ASTNode.buildAST(pr.result(), input);
        if (ast == null) {
            java.util.List<ASTNode> children = ASTNode.collectChildrenForAST(pr.result(), input);
            ast = new ASTNode(topRule, pr.result().pos(), pr.result().len(), children, input);
        }
        return ast;
    }

    /**
     * Convenience method to parse and return both AST and syntax errors.
     *
     * Overload 1: Parse with metagrammar string
     *
     * @param grammarText The grammar as a PEG metagrammar string
     * @param input The input string to parse
     * @param topRule The name of the top-level rule to parse
     * @return A SquirrelParseResult containing the AST and syntax errors
     */
    public static SquirrelParseResult squirrelParse(
        String grammarText,
        String input,
        String topRule
    ) {
        java.util.Map<String, Clause> rules = MetaGrammar.parseGrammar(grammarText);
        return squirrelParseInternal(rules, topRule, input);
    }

    /**
     * Convenience method to parse and return both AST and syntax errors.
     *
     * Overload 2: Parse with grammar rules map
     *
     * @param rules The grammar rules map
     * @param topRule The name of the top-level rule to parse
     * @param input The input string to parse
     * @return A SquirrelParseResult containing the AST and syntax errors
     */
    public static SquirrelParseResult squirrelParse(
        java.util.Map<String, Clause> rules,
        String topRule,
        String input
    ) {
        return squirrelParseInternal(rules, topRule, input);
    }

    /**
     * Internal implementation shared by both overloads.
     */
    private static SquirrelParseResult squirrelParseInternal(
        java.util.Map<String, Clause> rules,
        String topRule,
        String input
    ) {
        Parser parser = new Parser(rules, input);
        MatchResult matchResult = parser.parse(topRule);
        ASTNode ast = ASTNode.buildAST(matchResult, input, topRule);
        // Provide fallback empty AST node if buildAST returns null
        if (ast == null) {
            ast = new ASTNode(topRule, matchResult.pos(), matchResult.len(), new java.util.ArrayList<>(), input);
        }
        java.util.List<SyntaxError> syntaxErrors = Combinators.getSyntaxErrors(matchResult, input);
        return new SquirrelParseResult(ast, syntaxErrors);
    }

    /**
     * Result class for squirrelParse convenience method.
     */
    public record SquirrelParseResult(ASTNode ast, java.util.List<SyntaxError> syntaxErrors) {}
}
