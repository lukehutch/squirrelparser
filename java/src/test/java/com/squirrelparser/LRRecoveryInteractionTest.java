// ===========================================================================
// LEFT RECURSION + RECOVERY INTERACTION TESTS
// ===========================================================================
// These tests verify that error recovery works correctly during and after
// left-recursive expansion.

package com.squirrelparser;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class LRRecoveryInteractionTest {

    @Test
    void testLRInt01RecoveryDuringBaseCase() {
        // Error during LR base case - trailing captured with new invariant
        String grammar = """
            E <- E "+" "n" / "n" ;
            """;
        var r = TestUtils.testParse(grammar, "nX", "E");
        // Base case matches 'n', 'X' captured as trailing error
        assertTrue(r.ok(), "should succeed with trailing captured");
        assertEquals(1, r.errorCount(), "should have 1 error (trailing X)");
        assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("X")), "should skip X");
    }

    @Test
    void testLRInt02RecoveryDuringGrowth() {
        // Error during LR growth phase
        String grammar = """
            E <- E "+" "n" / "n" ;
            """;
        var r = TestUtils.testParse(grammar, "n+Xn", "E");
        assertTrue(r.ok(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("X")), "should skip X");
        // Base: n, Growth: n + [skip X] n
    }

    @Test
    void testLRInt03MultipleErrorsDuringExpansion() {
        // Multiple errors across multiple expansion iterations
        String grammar = """
            E <- E "+" "n" / "n" ;
            """;
        var r = TestUtils.testParse(grammar, "n+Xn+Yn+Zn", "E");
        assertTrue(r.ok(), "should succeed");
        assertEquals(3, r.errorCount(), "should have 3 errors");
        assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("X")), "should skip X");
        assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("Y")), "should skip Y");
        assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("Z")), "should skip Z");
    }

    @Test
    void testLRInt04NestedLrWithRecovery() {
        // E -> E + T | T, T -> T * n | n
        String grammar = """
            E <- E "+" T / T ;
            T <- T "*" "n" / "n" ;
            """;
        var r = TestUtils.testParse(grammar, "n*Xn+n*Yn", "E");
        assertTrue(r.ok(), "should succeed");
        assertEquals(2, r.errorCount(), "should have 2 errors (X in first term, Y in second term)");
        assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("X")), "should skip X");
        assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("Y")), "should skip Y");
    }

    @Test
    void testLRInt05LrExpansionStopsOnTrailingError() {
        // LR expands as far as possible, trailing captured with new invariant
        String grammar = """
            E <- E "+" "n" / "n" ;
            """;
        var r = TestUtils.testParse(grammar, "n+n+nX", "E");
        // Expansion: n, n+n, n+n+n (len=5), then 'X' captured as trailing
        assertTrue(r.ok(), "should succeed with trailing captured");
        assertEquals(1, r.errorCount(), "should have 1 error (trailing X)");
        assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("X")), "should skip X");
    }

    @Test
    void testLRInt06CacheInvalidationDuringRecovery() {
        // Phase 1: E@0 marked incomplete
        // Phase 2: E@0 must re-expand with recovery
        String grammar = """
            E <- E "+" "n" / "n" ;
            """;
        var r = TestUtils.testParse(grammar, "n+Xn", "E");
        assertTrue(r.ok(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("X")), "should skip X");
        // FIX #6: Cache must be invalidated for LR re-expansion
    }

    @Test
    void testLRInt07LrWithRepetitionAndRecovery() {
        // E -> E + n+ | n (nested repetition in LR)
        String grammar = """
            E <- E "+" "n"+ / "n" ;
            """;
        var r = TestUtils.testParse(grammar, "n+nXnn", "E");
        assertTrue(r.ok(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("X")), "should skip X in n+");
    }

    @Test
    void testLRInt08IsFromLRContextFlag() {
        // Successful LR results are marked with isFromLRContext
        // But this shouldn't prevent parent recovery (FIX #1)
        String grammar = """
            S <- E "end" ;
            E <- E "+" "n" / "n" ;
            """;
        var r = TestUtils.testParse(grammar, "n+nend");
        assertTrue(r.ok(), "should succeed");
        // E is left-recursive and successful, marked with isFromLRContext
        // But 'end' should still match (FIX #1: only MISMATCH blocks recovery)
    }

    @Test
    void testLRInt09FailedLrDoesntBlockRecovery() {
        // Failed LR (MISMATCH) should NOT be marked isFromLRContext
        // This allows parent to attempt recovery
        String grammar = """
            S <- E "x" ;
            E <- E "+" "n" / "n" ;
            """;
        // Input where E succeeds with recovery, then x matches
        var r = TestUtils.testParse(grammar, "nXnx");
        assertTrue(r.ok(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error (skip X)");
        // E matches 'nXn' with recovery, then 'x' matches
    }

    @Test
    void testLRInt10DeepLrNesting() {
        // Multiple levels of LR with recovery at each level
        String grammar = """
            S <- S "a" T / T ;
            T <- T "b" "x" / "x" ;
            """;
        var r = TestUtils.testParse(grammar, "xbXxaXxbx", "S");
        assertTrue(r.ok(), "should succeed");
        assertEquals(2, r.errorCount(), "should have 2 errors (X at both levels)");
        // Complex nesting: S and T both left-recursive, errors at both levels
    }
}
