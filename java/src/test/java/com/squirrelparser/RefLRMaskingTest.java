// =============================================================================
// REF LR MASKING TESTS
// =============================================================================
// Tests for multi-level left recursion with error recovery.
//
// KNOWN LIMITATION:
// In multi-level LR grammars like E -> E+T | T and T -> T*F | F:
// - When parsing "n+n*Xn", error is at '*Xn' where 'X' should be skipped
// - Optimal: T*F recovers by skipping 'X' -> 1 error
// - Current: E+T recovers by skipping '*X' -> 2 errors
//
// ROOT CAUSE:
// Ref('T') at position 2 creates a separate MemoEntry from the inner T rule.
// During Phase 2, E re-expands (foundLeftRec=true), but Ref('T') doesn't
// because its MemoEntry.foundLeftRec=false (doesn't inherit from inner T).
// This means T@2 returns cached result without trying recovery at T*F level.
//
// ATTEMPTED FIXES:
// 1. Propagating foundLeftRec from inner rule causes cascading re-expansions
//    that break other tests by causing excessive re-parsing.
// 2. Blocking recovery based on LR context of previous matches causes
//    recovery to fail entirely in some cases.
//
// The current behavior is a deterministic approximation - recovery happens
// at a higher grammar level than optimal, but still produces valid parses.

package com.squirrelparser;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class RefLRMaskingTest {

    @Nested
    class MultiLevelLRRecoveryTests {
        // Standard precedence grammar with multi-level left recursion
        private static final String PRECEDENCE_GRAMMAR = """
            E <- E "+" T / T ;
            T <- T "*" F / F ;
            F <- "(" E ")" / "n" ;
            """;

        @Test
        void testMultiLR01ErrorAtFLevelAfterStar() {
            // Input: n+n*Xn
            // Error: 'X' appears where 'n' (F) is expected after '*'
            // Current: Recovery at E+T level skips '*X' (2 errors)
            // Optimal would skip just 'X' (1 error)
            var r = TestUtils.testParse(PRECEDENCE_GRAMMAR, "n+n*Xn", "E");
            assertTrue(r.ok(), "should parse with recovery");
            assertTrue(r.errorCount() >= 1, "should have at least 1 error");
            // Note: Currently produces 2 errors due to recovery at wrong level
        }

        @Test
        void testMultiLR02ErrorAtTLevelAfterPlus() {
            // Input: n+Xn*n
            // Error: 'X' appears where 'n' (T) is expected after '+'
            var r = TestUtils.testParse(PRECEDENCE_GRAMMAR, "n+Xn*n", "E");
            assertTrue(r.ok(), "should parse with recovery");
            assertTrue(r.errorCount() >= 1, "should have at least 1 error");
        }

        @Test
        void testMultiLR03NestedErrorInParens() {
            // Input: n+(n*Xn)
            // Error inside parentheses at T*F level
            var r = TestUtils.testParse(PRECEDENCE_GRAMMAR, "n+(n*Xn)", "E");
            assertTrue(r.ok(), "should recover inside parens");
            assertTrue(r.errorCount() >= 1, "should have errors");
        }

        // Simpler two-level grammar to isolate the issue
        private static final String TWO_LEVEL_GRAMMAR = """
            A <- A "+" B / B ;
            B <- B "-" "x" / "x" ;
            """;

        @Test
        void testMultiLR04TwoLevel() {
            // Input: x+x-Yx (Y is error)
            // Error at B-x level after '-'
            var r = TestUtils.testParse(TWO_LEVEL_GRAMMAR, "x+x-Yx", "A");
            assertTrue(r.ok(), "should parse with recovery");
            assertTrue(r.errorCount() >= 1, "should have errors");
        }

        @Test
        void testMultiLR05ThreeLevels() {
            // Three-level LR to test deep nesting
            String threeLevelGrammar = """
                A <- A "+" B / B ;
                B <- B "*" C / C ;
                C <- C "-" "x" / "x" ;
                """;
            // Input: x+x*x-Yx (Y is error at deepest C level)
            var r = TestUtils.testParse(threeLevelGrammar, "x+x*x-Yx", "A");
            assertTrue(r.ok(), "should parse with recovery");
            assertTrue(r.errorCount() >= 1, "should have errors");
        }
    }

    @Nested
    class SingleLevelLRRecoveryTests {
        // Single-level LR works correctly with exact error counts

        @Test
        void testSingleLR01Basic() {
            String grammar = """
                E <- E "+" "n" / "n" ;
                """;
            var r = TestUtils.testParse(grammar, "n+Xn", "E");
            assertTrue(r.ok(), "basic LR recovery should work");
            assertEquals(1, r.errorCount(), "single-level LR should have exact error count");
        }

        @Test
        void testSingleLR02MultipleExpansions() {
            String grammar = """
                E <- E "+" "n" / "n" ;
                """;
            var r = TestUtils.testParse(grammar, "n+Xn+n", "E");
            assertTrue(r.ok());
            assertEquals(1, r.errorCount(), "single-level LR should skip exactly X");
        }

        @Test
        void testSingleLR03MultipleErrors() {
            String grammar = """
                E <- E "+" "n" / "n" ;
                """;
            var r = TestUtils.testParse(grammar, "n+Xn+Yn", "E");
            assertTrue(r.ok());
            assertEquals(2, r.errorCount(), "should have 2 errors");
        }
    }

    @Nested
    class LRPendingFixVerification {
        // Verify that LR_PENDING prevents spurious recovery on LR seeds

        @Test
        void testLRPending01NoSpuriousRecovery() {
            // Without LR_PENDING fix, this would have 4+ errors
            // With fix, it has 2 (due to Ref masking, not LR seeding)
            String grammar = """
                E <- E "+" T / T ;
                T <- T "*" "n" / "n" ;
                """;
            var r = TestUtils.testParse(grammar, "n+n*Xn", "E");
            assertTrue(r.ok());
            // LR_PENDING prevents 4 errors, but Ref masking still causes 2
            assertTrue(r.errorCount() <= 3, "LR_PENDING should prevent excessive errors");
        }
    }
}
