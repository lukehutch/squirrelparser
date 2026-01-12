package com.squirrelparser;

import org.junit.jupiter.api.Test;

import static com.squirrelparser.TestUtils.*;
import static org.junit.jupiter.api.Assertions.*;

/**
 * SECTION 10: MONOTONIC INVARIANT TESTS (50 tests)
 *
 * These tests verify that the monotonic improvement check only applies to
 * left-recursive clauses, not to all clauses. Without this fix, indirect
 * and interwoven left recursion would fail.
 */
class MonotonicTest {

    // ===========================================================================
    // ADDITIONAL LR PATTERNS (from Pegged wiki examples)
    // ===========================================================================
    // These test cases cover various left recursion patterns documented at:
    // https://github.com/PhilippeSigaud/Pegged/wiki/Left-Recursion

    // --- Direct LR: E <- E '+n' / 'n' ---
    private static final String DIRECT_LR_SIMPLE = """
        E <- E "+n" / "n" ;
        """;

    @Test
    void testLRDirect01n() {
        MatchResult r = parseForTree(DIRECT_LR_SIMPLE, "n", "E");
        assertTrue(r != null && r.len() == 1, "should parse n");
    }

    @Test
    void testLRDirect02n_plus_n() {
        MatchResult r = parseForTree(DIRECT_LR_SIMPLE, "n+n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n+n");
    }

    @Test
    void testLRDirect03n_plus_n_plus_n() {
        MatchResult r = parseForTree(DIRECT_LR_SIMPLE, "n+n+n", "E");
        assertTrue(r != null && r.len() == 5, "should parse n+n+n");
    }

    // --- Indirect LR: E <- F / 'n'; F <- E '+n' ---
    private static final String INDIRECT_LR_SIMPLE = """
        E <- F / "n" ;
        F <- E "+n" ;
        """;

    @Test
    void testLRIndirect01n() {
        MatchResult r = parseForTree(INDIRECT_LR_SIMPLE, "n", "E");
        assertTrue(r != null && r.len() == 1, "should parse n");
    }

    @Test
    void testLRIndirect02n_plus_n() {
        MatchResult r = parseForTree(INDIRECT_LR_SIMPLE, "n+n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n+n");
    }

    @Test
    void testLRIndirect03n_plus_n_plus_n() {
        MatchResult r = parseForTree(INDIRECT_LR_SIMPLE, "n+n+n", "E");
        assertTrue(r != null && r.len() == 5, "should parse n+n+n");
    }

    // --- Direct Hidden LR: E <- F? E '+n' / 'n'; F <- 'f' ---
    // The optional F? can match empty, making E left-recursive
    private static final String DIRECT_HIDDEN_LR = """
        E <- F? E "+n" / "n" ;
        F <- "f" ;
        """;

    @Test
    void testLRDirectHidden01n() {
        MatchResult r = parseForTree(DIRECT_HIDDEN_LR, "n", "E");
        assertTrue(r != null && r.len() == 1, "should parse n");
    }

    @Test
    void testLRDirectHidden02n_plus_n() {
        MatchResult r = parseForTree(DIRECT_HIDDEN_LR, "n+n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n+n");
    }

    @Test
    void testLRDirectHidden03n_plus_n_plus_n() {
        MatchResult r = parseForTree(DIRECT_HIDDEN_LR, "n+n+n", "E");
        assertTrue(r != null && r.len() == 5, "should parse n+n+n");
    }

    @Test
    void testLRDirectHidden04fn_plus_n() {
        // With the 'f' prefix, right-recursive path
        MatchResult r = parseForTree(DIRECT_HIDDEN_LR, "fn+n", "E");
        assertTrue(r != null && r.len() == 4, "should parse fn+n");
    }

    // --- Indirect Hidden LR: E <- F E '+n' / 'n'; F <- "abc" / 'd'* ---
    // F can match empty (via 'd'*), making E left-recursive
    private static final String INDIRECT_HIDDEN_LR = """
        E <- F E "+n" / "n" ;
        F <- "abc" / "d"* ;
        """;

    @Test
    void testLRIndirectHidden01n() {
        MatchResult r = parseForTree(INDIRECT_HIDDEN_LR, "n", "E");
        assertTrue(r != null && r.len() == 1, "should parse n");
    }

    @Test
    void testLRIndirectHidden02n_plus_n() {
        MatchResult r = parseForTree(INDIRECT_HIDDEN_LR, "n+n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n+n");
    }

    @Test
    void testLRIndirectHidden03n_plus_n_plus_n() {
        MatchResult r = parseForTree(INDIRECT_HIDDEN_LR, "n+n+n", "E");
        assertTrue(r != null && r.len() == 5, "should parse n+n+n");
    }

    @Test
    void testLRIndirectHidden04abcn_plus_n() {
        // With 'abc' prefix, right-recursive path
        MatchResult r = parseForTree(INDIRECT_HIDDEN_LR, "abcn+n", "E");
        assertTrue(r != null && r.len() == 6, "should parse abcn+n");
    }

    @Test
    void testLRIndirectHidden05ddn_plus_n() {
        // With 'dd' prefix, right-recursive path
        MatchResult r = parseForTree(INDIRECT_HIDDEN_LR, "ddn+n", "E");
        assertTrue(r != null && r.len() == 5, "should parse ddn+n");
    }

    // --- Multi-step Indirect LR: E <- F '+n' / 'n'; F <- "gh" / J; J <- 'k' / E 'l' ---
    // Three-step indirect cycle: E -> F -> J -> E
    private static final String MULTI_STEP_LR = """
        E <- F "+n" / "n" ;
        F <- "gh" / J ;
        J <- "k" / E "l" ;
        """;

    @Test
    void testLRMultiStep01n() {
        MatchResult r = parseForTree(MULTI_STEP_LR, "n", "E");
        assertTrue(r != null && r.len() == 1, "should parse n");
    }

    @Test
    void testLRMultiStep02gh_plus_n() {
        // F matches "gh"
        MatchResult r = parseForTree(MULTI_STEP_LR, "gh+n", "E");
        assertTrue(r != null && r.len() == 4, "should parse gh+n");
    }

    @Test
    void testLRMultiStep03k_plus_n() {
        // F -> J -> 'k'
        MatchResult r = parseForTree(MULTI_STEP_LR, "k+n", "E");
        assertTrue(r != null && r.len() == 3, "should parse k+n");
    }

    @Test
    void testLRMultiStep04nl_plus_n() {
        // E <- F '+n' where F <- J where J <- E 'l'
        // So: E matches 'n', then 'l', giving 'nl' for J, for F
        // Then F '+n' gives 'nl+n'
        MatchResult r = parseForTree(MULTI_STEP_LR, "nl+n", "E");
        assertTrue(r != null && r.len() == 4, "should parse nl+n");
    }

    @Test
    void testLRMultiStep05nl_plus_nl_plus_n() {
        // Nested multi-step LR
        MatchResult r = parseForTree(MULTI_STEP_LR, "nl+nl+n", "E");
        assertTrue(r != null && r.len() == 7, "should parse nl+nl+n");
    }

    // --- Direct + Indirect LR (Interwoven): L <- P '.x' / 'x'; P <- P '(n)' / L ---
    // Two interlocking cycles: L->P->L (indirect) and P->P (direct)
    private static final String INTERWOVEN_LR = """
        L <- P ".x" / "x" ;
        P <- P "(n)" / L ;
        """;

    @Test
    void testLRInterwoven01x() {
        MatchResult r = parseForTree(INTERWOVEN_LR, "x", "L");
        assertTrue(r != null && r.len() == 1, "should parse x");
    }

    @Test
    void testLRInterwoven02x_dot_x() {
        MatchResult r = parseForTree(INTERWOVEN_LR, "x.x", "L");
        assertTrue(r != null && r.len() == 3, "should parse x.x");
    }

    @Test
    void testLRInterwoven03x_paren_n_dot_x() {
        MatchResult r = parseForTree(INTERWOVEN_LR, "x(n).x", "L");
        assertTrue(r != null && r.len() == 6, "should parse x(n).x");
    }

    @Test
    void testLRInterwoven04x_paren_n_paren_n_dot_x() {
        MatchResult r = parseForTree(INTERWOVEN_LR, "x(n)(n).x", "L");
        assertTrue(r != null && r.len() == 9, "should parse x(n)(n).x");
    }

    // --- Multiple Interlocking LR Cycles ---
    // E <- F 'n' / 'n'
    // F <- E '+' I* / G '-'
    // G <- H 'm' / E
    // H <- G 'l'
    // I <- '(' A+ ')'
    // A <- 'a'
    // Cycles: E->F->E, F->G->E, G->H->G
    private static final String INTERLOCKING_LR = """
        E <- F "n" / "n" ;
        F <- E "+" I* / G "-" ;
        G <- H "m" / E ;
        H <- G "l" ;
        I <- "(" A+ ")" ;
        A <- "a" ;
        """;

    @Test
    void testLRInterlocking01n() {
        MatchResult r = parseForTree(INTERLOCKING_LR, "n", "E");
        assertTrue(r != null && r.len() == 1, "should parse n");
    }

    @Test
    void testLRInterlocking02n_plus_n() {
        // E <- F 'n' where F <- E '+'
        MatchResult r = parseForTree(INTERLOCKING_LR, "n+n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n+n");
    }

    @Test
    void testLRInterlocking03n_minus_n() {
        // E <- F 'n' where F <- G '-' where G <- E
        MatchResult r = parseForTree(INTERLOCKING_LR, "n-n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n-n");
    }

    @Test
    void testLRInterlocking04nlm_minus_n() {
        // G <- H 'm' where H <- G 'l', cycle G->H->G
        MatchResult r = parseForTree(INTERLOCKING_LR, "nlm-n", "E");
        assertTrue(r != null && r.len() == 5, "should parse nlm-n");
    }

    @Test
    void testLRInterlocking05n_plus_aaa_n() {
        // E '+' I* where I <- '(' A+ ')'
        MatchResult r = parseForTree(INTERLOCKING_LR, "n+(aaa)n", "E");
        assertTrue(r != null && r.len() == 8, "should parse n+(aaa)n");
    }

    @Test
    void testLRInterlocking06nlm_minus_n_plus_aaa_n() {
        // Complex combination of all cycles
        MatchResult r = parseForTree(INTERLOCKING_LR, "nlm-n+(aaa)n", "E");
        assertTrue(r != null && r.len() == 12, "should parse nlm-n+(aaa)n");
    }

    // --- LR Precedence Grammar ---
    // E <- E '+' T / E '-' T / T
    // T <- T '*' F / T '/' F / F
    // F <- '(' E ')' / 'n'
    private static final String PRECEDENCE_GRAMMAR = """
        E <- E "+" T / E "-" T / T ;
        T <- T "*" F / T "/" F / F ;
        F <- "(" E ")" / "n" ;
        """;

    @Test
    void testLRPrecedence01n() {
        MatchResult r = parseForTree(PRECEDENCE_GRAMMAR, "n", "E");
        assertTrue(r != null && r.len() == 1, "should parse n");
    }

    @Test
    void testLRPrecedence02n_plus_n() {
        MatchResult r = parseForTree(PRECEDENCE_GRAMMAR, "n+n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n+n");
    }

    @Test
    void testLRPrecedence03n_times_n() {
        MatchResult r = parseForTree(PRECEDENCE_GRAMMAR, "n*n", "E");
        assertTrue(r != null && r.len() == 3, "should parse n*n");
    }

    @Test
    void testLRPrecedence04n_plus_n_times_n() {
        // Precedence: n+(n*n) not (n+n)*n
        MatchResult r = parseForTree(PRECEDENCE_GRAMMAR, "n+n*n", "E");
        assertTrue(r != null && r.len() == 5, "should parse n+n*n");
    }

    @Test
    void testLRPrecedence05n_plus_n_times_n_plus_n_div_n() {
        MatchResult r = parseForTree(PRECEDENCE_GRAMMAR, "n+n*n+n/n", "E");
        assertTrue(r != null && r.len() == 9, "should parse n+n*n+n/n");
    }

    @Test
    void testLRPrecedence06paren_n_plus_n_times_n() {
        MatchResult r = parseForTree(PRECEDENCE_GRAMMAR, "(n+n)*n", "E");
        assertTrue(r != null && r.len() == 7, "should parse (n+n)*n");
    }

    // --- LR Error Recovery ---
    @Test
    void testLRRecoveryLeadingError() {
        // Input '+n+n+n+' starts with '+' which is invalid
        ParseTestResult result = testParse(DIRECT_LR_SIMPLE, "+n+n+n+", "E");
        // Recovery should skip leading '+' and parse rest, or fail
        // The leading '+' can potentially be skipped as garbage
        if (result.ok()) {
            assertTrue(result.errorCount() >= 1, "should have errors if succeeded");
        }
    }

    @Test
    void testLRRecoveryTrailingPlus() {
        // Input 'n+n+n+' has trailing '+' with no 'n' after
        ParseResult parseResult = SquirrelParser.squirrelParsePT(
            DIRECT_LR_SIMPLE,
            "E",
            "n+n+n+"
        );
        MatchResult result = parseResult.root();
        // Should parse 'n+n+n' and either fail on trailing '+' or recover
        if (!result.isMismatch()) {
            // If it succeeded, it should have used recovery
            assertTrue(result.len() >= 5, "should parse at least n+n+n");
        }
    }

    // --- Indirect Left Recursion (Fig7b): A <- B / 'x'; B <- (A 'y') / (A 'x') ---
    private static final String FIG7B = """
        A <- B / "x" ;
        B <- A "y" / A "x" ;
        """;

    @Test
    void testMILR01x() {
        MatchResult r = parseForTree(FIG7B, "x", "A");
        assertTrue(r != null && r.len() == 1, "should parse x");
    }

    @Test
    void testMILR02xx() {
        MatchResult r = parseForTree(FIG7B, "xx", "A");
        assertTrue(r != null && r.len() == 2, "should parse xx");
    }

    @Test
    void testMILR03xy() {
        MatchResult r = parseForTree(FIG7B, "xy", "A");
        assertTrue(r != null && r.len() == 2, "should parse xy");
    }

    @Test
    void testMILR04xxy() {
        MatchResult r = parseForTree(FIG7B, "xxy", "A");
        assertTrue(r != null && r.len() == 3, "should parse xxy");
    }

    @Test
    void testMILR05xxyx() {
        MatchResult r = parseForTree(FIG7B, "xxyx", "A");
        assertTrue(r != null && r.len() == 4, "should parse xxyx");
    }

    @Test
    void testMILR06xyx() {
        MatchResult r = parseForTree(FIG7B, "xyx", "A");
        assertTrue(r != null && r.len() == 3, "should parse xyx");
    }

    // --- Interwoven Left Recursion (Fig7f): L <- P '.x' / 'x'; P <- P '(n)' / L ---
    private static final String FIG7F = """
        L <- P ".x" / "x" ;
        P <- P "(n)" / L ;
        """;

    @Test
    void testMIW01x() {
        MatchResult r = parseForTree(FIG7F, "x", "L");
        assertTrue(r != null && r.len() == 1, "should parse x");
    }

    @Test
    void testMIW02x_dot_x() {
        MatchResult r = parseForTree(FIG7F, "x.x", "L");
        assertTrue(r != null && r.len() == 3, "should parse x.x");
    }

    @Test
    void testMIW03x_paren_n_dot_x() {
        MatchResult r = parseForTree(FIG7F, "x(n).x", "L");
        assertTrue(r != null && r.len() == 6, "should parse x(n).x");
    }

    @Test
    void testMIW04x_paren_n_paren_n_dot_x() {
        MatchResult r = parseForTree(FIG7F, "x(n)(n).x", "L");
        assertTrue(r != null && r.len() == 9, "should parse x(n)(n).x");
    }

    @Test
    void testMIW05x_dot_x_paren_n_paren_n_dot_x_dot_x() {
        MatchResult r = parseForTree(FIG7F, "x.x(n)(n).x.x", "L");
        assertTrue(r != null && r.len() == 13, "should parse x.x(n)(n).x.x");
    }

    // --- Optional-Dependent Left Recursion (Fig7d): A <- 'x'? (A 'y' / A / 'y') ---
    private static final String FIG7D = """
        A <- "x"? (A "y" / A / "y") ;
        """;

    @Test
    void testMOD01y() {
        MatchResult r = parseForTree(FIG7D, "y", "A");
        assertTrue(r != null && r.len() == 1, "should parse y");
    }

    @Test
    void testMOD02xy() {
        MatchResult r = parseForTree(FIG7D, "xy", "A");
        assertTrue(r != null && r.len() == 2, "should parse xy");
    }

    @Test
    void testMOD03xxyyy() {
        MatchResult r = parseForTree(FIG7D, "xxyyy", "A");
        assertTrue(r != null && r.len() == 5, "should parse xxyyy");
    }

    // --- Input-Dependent Left Recursion (Fig7c): A <- B / 'z'; B <- ('x' A) / (A 'y') ---
    private static final String FIG7C = """
        A <- B / "z" ;
        B <- "x" A / A "y" ;
        """;

    @Test
    void testMID01z() {
        MatchResult r = parseForTree(FIG7C, "z", "A");
        assertTrue(r != null && r.len() == 1, "should parse z");
    }

    @Test
    void testMID02xz() {
        MatchResult r = parseForTree(FIG7C, "xz", "A");
        assertTrue(r != null && r.len() == 2, "should parse xz");
    }

    @Test
    void testMID03zy() {
        MatchResult r = parseForTree(FIG7C, "zy", "A");
        assertTrue(r != null && r.len() == 2, "should parse zy");
    }

    @Test
    void testMID04xxzyyy() {
        MatchResult r = parseForTree(FIG7C, "xxzyyy", "A");
        assertTrue(r != null && r.len() == 6, "should parse xxzyyy");
    }

    // --- Triple-nested indirect LR ---
    private static final String TRIPLE_LR = """
        A <- B / "a" ;
        B <- C / "b" ;
        C <- A "x" / "c" ;
        """;

    @Test
    void testMTLR01a() {
        MatchResult r = parseForTree(TRIPLE_LR, "a", "A");
        assertTrue(r != null && r.len() == 1, "should parse a");
    }

    @Test
    void testMTLR02ax() {
        MatchResult r = parseForTree(TRIPLE_LR, "ax", "A");
        assertTrue(r != null && r.len() == 2, "should parse ax");
    }

    @Test
    void testMTLR03axx() {
        MatchResult r = parseForTree(TRIPLE_LR, "axx", "A");
        assertTrue(r != null && r.len() == 3, "should parse axx");
    }

    @Test
    void testMTLR04axxx() {
        MatchResult r = parseForTree(TRIPLE_LR, "axxx", "A");
        assertTrue(r != null && r.len() == 4, "should parse axxx");
    }
}
