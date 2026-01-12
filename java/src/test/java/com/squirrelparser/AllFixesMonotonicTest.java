package com.squirrelparser;

import static com.squirrelparser.TestUtils.countDeletions;
import static com.squirrelparser.TestUtils.testParse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;

import org.junit.jupiter.api.Test;

import com.squirrelparser.TestUtils.ParseTestResult;

/**
 * SECTION 11: ALL SIX FIXES WITH MONOTONIC INVARIANT (20 tests)
 *
 * Verify all six error recovery fixes work correctly with the monotonic
 * invariant fix applied.
 */
class AllFixesMonotonicTest {

    // --- FIX #1: isComplete propagation with LR ---
    private static final String EXPR_LR = """
        E <- E "+" N / N ;
        N <- [0-9]+ ;
        """;

    @Test
    void testF1LRClean() {
        ParseTestResult r = testParse(EXPR_LR, "1+2+3", "E");
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testF1LRRecovery() {
        ParseTestResult r = testParse(EXPR_LR, "1+Z2+3", "E");
        assertTrue(r.ok(), "should succeed");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
        assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    // --- FIX #2: Discovery-only incomplete marking with LR ---
    private static final String REP_LR = """
        E <- E "+" T / T ;
        T <- "x"+ ;
        """;

    @Test
    void testF2LRClean() {
        ParseTestResult r = testParse(REP_LR, "x+xx+xxx", "E");
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testF2LRError() {
        ParseTestResult r = testParse(REP_LR, "x+xZx+xxx", "E");
        assertTrue(r.ok(), "should succeed");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
    }

    // --- FIX #3: Cache isolation with LR ---
    private static final String CACHE_LR = """
        S <- "[" E "]" ;
        E <- E "+" N / N ;
        N <- "x"+ ;
        """;

    @Test
    void testF3LRClean() {
        ParseTestResult r = testParse(CACHE_LR, "[x+xx]");
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testF3LRRecovery() {
        ParseTestResult r = testParse(CACHE_LR, "[x+Zxx]");
        assertTrue(r.ok(), "should succeed");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
    }

    // --- FIX #4: Pre-element bound check with LR ---
    private static final String BOUND_LR = """
        S <- ("[" E "]")+ ;
        E <- E "+" N / N ;
        N <- [0-9]+ ;
        """;

    @Test
    void testF4LRClean() {
        ParseTestResult r = testParse(BOUND_LR, "[1+2][3+4]");
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testF4LRRecovery() {
        ParseTestResult r = testParse(BOUND_LR, "[1+Z2][3+4]");
        assertTrue(r.ok(), "should succeed");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
    }

    // --- FIX #5: Optional fallback incomplete with LR ---
    private static final String OPT_LR = """
        S <- E ";"? ;
        E <- E "+" N / N ;
        N <- [0-9]+ ;
        """;

    @Test
    void testF5LRWithOpt() {
        ParseTestResult r = testParse(OPT_LR, "1+2+3;");
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testF5LRWithoutOpt() {
        ParseTestResult r = testParse(OPT_LR, "1+2+3");
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    // --- FIX #6: Conservative EOF recovery with LR ---
    private static final String EOF_LR = """
        S <- E "!" ;
        E <- E "+" N / N ;
        N <- [0-9]+ ;
        """;

    @Test
    void testF6LRClean() {
        ParseTestResult r = testParse(EOF_LR, "1+2+3!");
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testF6LRDeletion() {
        ParseResult parseResult = SquirrelParser.squirrelParsePT(EOF_LR, "S", "1+2+3");
        MatchResult result = parseResult.root();
        assertTrue(!result.isMismatch(), "should succeed with recovery");
        assertTrue(countDeletions(List.of(result)) >= 1, "should have at least 1 deletion");
    }

    // --- Combined: Expression grammar with all features ---
    private static final String FULL_GRAMMAR = """
        Program <- (Expr ";"?)+ ;
        Expr <- Expr "+" Term / Term ;
        Term <- Term "*" Factor / Factor ;
        Factor <- "(" Expr ")" / Num ;
        Num <- [0-9]+ ;
        """;

    @Test
    void testFullCleanSimple() {
        ParseTestResult r = testParse(FULL_GRAMMAR, "1+2*3", "Program");
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testFullCleanSemi() {
        ParseTestResult r = testParse(FULL_GRAMMAR, "1+2;3*4", "Program");
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testFullCleanNested() {
        ParseTestResult r = testParse(FULL_GRAMMAR, "(1+2)*(3+4)", "Program");
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testFullRecoverySkip() {
        ParseTestResult r = testParse(FULL_GRAMMAR, "1+Z2*3", "Program");
        assertTrue(r.ok(), "should succeed");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
    }

    // --- Deep left recursion ---
    private static final String DEEP_LR = """
        E <- E "+" N / N ;
        N <- [0-9] ;
        """;

    @Test
    void testDeepLRClean() {
        ParseTestResult r = testParse(DEEP_LR, "1+2+3+4+5+6+7+8+9", "E");
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testDeepLRRecovery() {
        ParseTestResult r = testParse(DEEP_LR, "1+2+Z3+4+5", "E");
        assertTrue(r.ok(), "should succeed");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
    }
}
