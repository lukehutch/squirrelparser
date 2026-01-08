package com.squirrelparser;

import static com.squirrelparser.TestUtils.countDeletions;
import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Optional;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.CharRange;
import com.squirrelparser.Terminals.Str;

/**
 * SECTION 11: ALL SIX FIXES WITH MONOTONIC INVARIANT (18 tests)
 * Port of all_fixes_monotonic_test.dart
 *
 * Verify all six error recovery fixes work correctly with the monotonic
 * invariant fix applied.
 */
class AllFixesMonotonicTest {

    // --- FIX #1: isComplete propagation with LR ---
    private static final Map<String, Clause> exprLR = Map.of(
        "E", new First(
            new Seq(new Ref("E"), new Str("+"), new Ref("N")),
            new Ref("N")
        ),
        "N", new OneOrMore(new CharRange("0", "9"))
    );

    @Test
    void testF1LRClean() {
        var r = parse(exprLR, "1+2+3", "E");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testF1LRRecovery() {
        var r = parse(exprLR, "1+Z2+3", "E");
        assertTrue(r.success(), "should succeed");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
        assertTrue(r.skipped().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    // --- FIX #2: Discovery-only incomplete marking with LR ---
    private static final Map<String, Clause> repLR = Map.of(
        "E", new First(
            new Seq(new Ref("E"), new Str("+"), new Ref("T")),
            new Ref("T")
        ),
        "T", new OneOrMore(new Str("x"))
    );

    @Test
    void testF2LRClean() {
        var r = parse(repLR, "x+xx+xxx", "E");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testF2LRError() {
        var r = parse(repLR, "x+xZx+xxx", "E");
        assertTrue(r.success(), "should succeed");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
    }

    // --- FIX #3: Cache isolation with LR ---
    private static final Map<String, Clause> cacheLR = Map.of(
        "S", new Seq(new Str("["), new Ref("E"), new Str("]")),
        "E", new First(
            new Seq(new Ref("E"), new Str("+"), new Ref("N")),
            new Ref("N")
        ),
        "N", new OneOrMore(new Str("x"))
    );

    @Test
    void testF3LRClean() {
        var r = parse(cacheLR, "[x+xx]");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testF3LRRecovery() {
        var r = parse(cacheLR, "[x+Zxx]");
        assertTrue(r.success(), "should succeed");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
    }

    // --- FIX #4: Pre-element bound check with LR ---
    private static final Map<String, Clause> boundLR = Map.of(
        "S", new OneOrMore(new Seq(new Str("["), new Ref("E"), new Str("]"))),
        "E", new First(
            new Seq(new Ref("E"), new Str("+"), new Ref("N")),
            new Ref("N")
        ),
        "N", new OneOrMore(new CharRange("0", "9"))
    );

    @Test
    void testF4LRClean() {
        var r = parse(boundLR, "[1+2][3+4]");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testF4LRRecovery() {
        var r = parse(boundLR, "[1+Z2][3+4]");
        assertTrue(r.success(), "should succeed");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
    }

    // --- FIX #5: Optional fallback incomplete with LR ---
    private static final Map<String, Clause> optLR = Map.of(
        "S", new Seq(new Ref("E"), new Optional(new Str(";"))),
        "E", new First(
            new Seq(new Ref("E"), new Str("+"), new Ref("N")),
            new Ref("N")
        ),
        "N", new OneOrMore(new CharRange("0", "9"))
    );

    @Test
    void testF5LRWithOpt() {
        var r = parse(optLR, "1+2+3;");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testF5LRWithoutOpt() {
        var r = parse(optLR, "1+2+3");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    // --- FIX #6: Conservative EOF recovery with LR ---
    private static final Map<String, Clause> eofLR = Map.of(
        "S", new Seq(new Ref("E"), new Str("!")),
        "E", new First(
            new Seq(new Ref("E"), new Str("+"), new Ref("N")),
            new Ref("N")
        ),
        "N", new OneOrMore(new CharRange("0", "9"))
    );

    @Test
    void testF6LRClean() {
        var r = parse(eofLR, "1+2+3!");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testF6LRDeletion() {
        var parser = new Parser(eofLR, "1+2+3");
        var result = parser.parse("S");
        assertTrue(result != null && !result.isMismatch(), "should succeed with recovery");
        assertTrue(countDeletions(result) >= 1, "should have at least 1 deletion");
    }

    // --- Combined: Expression grammar with all features ---
    private static final Map<String, Clause> fullGrammar = Map.of(
        "Program", new OneOrMore(new Seq(new Ref("Expr"), new Optional(new Str(";")))),
        "Expr", new First(
            new Seq(new Ref("Expr"), new Str("+"), new Ref("Term")),
            new Ref("Term")
        ),
        "Term", new First(
            new Seq(new Ref("Term"), new Str("*"), new Ref("Factor")),
            new Ref("Factor")
        ),
        "Factor", new First(
            new Seq(new Str("("), new Ref("Expr"), new Str(")")),
            new Ref("Num")
        ),
        "Num", new OneOrMore(new CharRange("0", "9"))
    );

    @Test
    void testFULLCleanSimple() {
        var r = parse(fullGrammar, "1+2*3", "Program");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testFULLCleanSemi() {
        var r = parse(fullGrammar, "1+2;3*4", "Program");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testFULLCleanNested() {
        var r = parse(fullGrammar, "(1+2)*(3+4)", "Program");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testFULLRecoverySkip() {
        var r = parse(fullGrammar, "1+Z2*3", "Program");
        assertTrue(r.success(), "should succeed");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
    }

    // --- Deep left recursion ---
    private static final Map<String, Clause> deepLR = Map.of(
        "E", new First(
            new Seq(new Ref("E"), new Str("+"), new Ref("N")),
            new Ref("N")
        ),
        "N", new CharRange("0", "9")
    );

    @Test
    void testDEEPLRClean() {
        var r = parse(deepLR, "1+2+3+4+5+6+7+8+9", "E");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testDEEPLRRecovery() {
        var r = parse(deepLR, "1+2+Z3+4+5", "E");
        assertTrue(r.success(), "should succeed");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
    }
}
