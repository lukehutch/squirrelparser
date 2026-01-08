package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.Str;

/**
 * LEFT RECURSION + RECOVERY INTERACTION TESTS
 * Port of lr_recovery_interaction_test.dart
 *
 * These tests verify that error recovery works correctly during and after
 * left-recursive expansion.
 */
class LRRecoveryInteractionTest {

    @Test
    void testLRINT01_recoveryDuringBaseCase() {
        // Error during LR base case - terminal at top level can't recover
        var result = parse(Map.of(
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            )
        ), "nX", "E");
        // Base case matches 'n', but 'X' remains - should fail (not all input consumed)
        assertFalse(result.success(), "should fail (trailing X not consumed)");
    }

    @Test
    void testLRINT02_recoveryDuringGrowth() {
        // Error during LR growth phase
        var result = parse(Map.of(
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            )
        ), "n+Xn", "E");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("X"), "should skip X");
        // Base: n, Growth: n + [skip X] n
    }

    @Test
    void testLRINT03_multipleErrorsDuringExpansion() {
        // Multiple errors across multiple expansion iterations
        var result = parse(Map.of(
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            )
        ), "n+Xn+Yn+Zn", "E");
        assertTrue(result.success(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
        assertTrue(result.skipped().contains("X"), "should skip X");
        assertTrue(result.skipped().contains("Y"), "should skip Y");
        assertTrue(result.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testLRINT04_nestedLRWithRecovery() {
        // E -> E + T | T, T -> T * n | n
        var result = parse(Map.of(
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Ref("T")),
                new Ref("T")
            ),
            "T", new First(
                new Seq(new Ref("T"), new Str("*"), new Str("n")),
                new Str("n")
            )
        ), "n*Xn+n*Yn", "E");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(),
            "should have 2 errors (X in first term, Y in second term)");
        assertTrue(result.skipped().contains("X"), "should skip X");
        assertTrue(result.skipped().contains("Y"), "should skip Y");
    }

    @Test
    void testLRINT05_lrExpansionStopsOnTrailingError() {
        // LR expands as far as possible, trailing garbage fails
        var result = parse(Map.of(
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            )
        ), "n+n+nX", "E");
        // Expansion: n, n+n, n+n+n (len=5), then 'X' at position 5
        // At EOF, can delete grammar, but there's no more grammar to match 'X'
        assertFalse(result.success(), "should fail (trailing garbage at EOF)");
    }

    @Test
    void testLRINT06_cacheInvalidationDuringRecovery() {
        // Phase 1: E@0 marked incomplete
        // Phase 2: E@0 must re-expand with recovery
        var result = parse(Map.of(
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            )
        ), "n+Xn", "E");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("X"), "should skip X");
        // FIX #6: Cache must be invalidated for LR re-expansion
    }

    @Test
    void testLRINT07_lrWithRepetitionAndRecovery() {
        // E -> E + n+ | n (nested repetition in LR)
        var result = parse(Map.of(
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new OneOrMore(new Str("n"))),
                new Str("n")
            )
        ), "n+nXnn", "E");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("X"), "should skip X in n+");
    }

    @Test
    void testLRINT08_isFromLRContextFlag() {
        // Successful LR results are marked with isFromLRContext
        // But this shouldn't prevent parent recovery (FIX #1)
        var result = parse(Map.of(
            "S", new Seq(new Ref("E"), new Str("end")),
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            )
        ), "n+nend");
        assertTrue(result.success(), "should succeed");
        // E is left-recursive and successful, marked with isFromLRContext
        // But 'end' should still match (FIX #1: only MISMATCH blocks recovery)
    }

    @Test
    void testLRINT09_failedLRDoesntBlockRecovery() {
        // Failed LR (MISMATCH) should NOT be marked isFromLRContext
        // This allows parent to attempt recovery
        Map<String, Clause> grammar = Map.of(
            "S", new Seq(new Ref("E"), new Str("x")),
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            )
        );

        // Input where E succeeds with recovery, then x matches
        var result = parse(grammar, "nXnx");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (skip X)");
        // E matches 'nXn' with recovery, then 'x' matches
    }

    @Test
    void testLRINT10_deepLRNesting() {
        // Multiple levels of LR with recovery at each level
        var result = parse(Map.of(
            "S", new First(
                new Seq(new Ref("S"), new Str("a"), new Ref("T")),
                new Ref("T")
            ),
            "T", new First(
                new Seq(new Ref("T"), new Str("b"), new Str("x")),
                new Str("x")
            )
        ), "xbXxaXxbx", "S");
        assertTrue(result.success(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors (X at both levels)");
        // Complex nesting: S and T both left-recursive, errors at both levels
    }
}
