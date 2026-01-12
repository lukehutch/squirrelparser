// =============================================================================
// CACHE CLEARING BUG TESTS (Document 4 fix) and LR RE-EXPANSION TESTS
// =============================================================================

package com.squirrelparser;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class CacheClearingLRTest {

    // ===========================================================================
    // CACHE CLEARING BUG TESTS (Document 4 fix)
    // ===========================================================================

    @Nested
    class CacheClearingBugTests {
        // --- Non-LR incomplete result must be cleared when recovery state changes ---
        // Bug: foundLeftRec && condition prevents clearing non-LR incomplete results

        private static final String STALE_CLEAR_GRAMMAR = """
            S <- A+ "z" ;
            A <- "ab" / "a" ;
            """;

        @Test
        void testF401StaleNonLRIncomplete() {
            // Phase 1: A+ matches 'a' at 0, fails at 'X'. Incomplete, len=1.
            // Phase 2: A+ should skip 'X', match 'ab', get len=4
            // Bug: stale len=1 result returned without clearing
            var r = TestUtils.testParse(STALE_CLEAR_GRAMMAR, "aXabz");
            assertTrue(r.ok(), "should recover by skipping X");
            assertEquals(1, r.errorCount(), "should have 1 error");
            assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("X")), "should skip X");
        }

        @Test
        void testF402StaleNonLRIncompleteMulti() {
            // Multiple recovery points in non-LR repetition
            var r = TestUtils.testParse(STALE_CLEAR_GRAMMAR, "aXaYabz");
            assertTrue(r.ok(), "should recover from multiple errors");
            assertEquals(2, r.errorCount(), "should have 2 errors");
        }

        // --- probe() during Phase 2 must get fresh results ---
        private static final String PROBE_CONTEXT_GRAMMAR = """
            S <- A B ;
            A <- "a"+ ;
            B <- "a"* "z" ;
            """;

        @Test
        void testF403ProbeContextPhase2() {
            // Bounded repetition uses probe() to check if B can match
            // probe() must not reuse stale Phase 2 results
            var r = TestUtils.testParse(PROBE_CONTEXT_GRAMMAR, "aaaXz");
            assertTrue(r.ok(), "should recover");
            assertEquals(1, r.errorCount(), "should have 1 error");
        }

        @Test
        void testF404ProbeAtBoundary() {
            // Edge case: probe at exact boundary between clauses
            var r = TestUtils.testParse(PROBE_CONTEXT_GRAMMAR, "aXaz");
            assertTrue(r.ok(), "should recover at boundary");
        }
    }

    // ===========================================================================
    // LR RE-EXPANSION TESTS (Complete LR + recovery context change)
    // ===========================================================================

    @Nested
    class LRReExpansionTests {
        // --- Direct LR must re-expand in Phase 2 ---
        // NOTE: Using "+" "n" instead of "+n" to allow
        // recovery to skip characters between '+' and 'n'.
        private static final String DIRECT_LR_REEXPAND = """
            E <- E "+" "n" / "n" ;
            """;

        @Test
        void testF1LR01ReexpandSimple() {
            // Phase 1: E matches 'n' (len=1), complete
            // Phase 2: must re-expand to skip 'X' and get 'n+n+n' (len=6)
            var r = TestUtils.testParse(DIRECT_LR_REEXPAND, "n+Xn+n", "E");
            assertTrue(r.ok(), "LR must re-expand in Phase 2");
            assertEquals(1, r.errorCount(), "should have 1 error");
            assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("X")), "should skip X");
        }

        @Test
        void testF1LR02ReexpandMultipleErrors() {
            // Multiple errors in LR expansion
            var r = TestUtils.testParse(DIRECT_LR_REEXPAND, "n+Xn+Yn+n", "E");
            assertTrue(r.ok(), "LR should handle multiple errors");
            assertEquals(2, r.errorCount(), "should have 2 errors");
        }

        @Test
        void testF1LR03ReexpandAtStart() {
            // Error between base 'n' and '+' - recovery should skip X
            var r = TestUtils.testParse(DIRECT_LR_REEXPAND, "nX+n+n", "E");
            assertTrue(r.ok(), "should recover by skipping X");
            assertEquals(1, r.errorCount(), "should have 1 error");
        }

        // --- Indirect LR re-expansion ---
        private static final String INDIRECT_LR_REEXPAND = """
            E <- F / "n" ;
            F <- E "+" "n" ;
            """;

        @Test
        void testF1LR04IndirectReexpand() {
            var r = TestUtils.testParse(INDIRECT_LR_REEXPAND, "n+Xn+n", "E");
            assertTrue(r.ok(), "indirect LR must re-expand");
            assertEquals(1, r.errorCount(), "should have 1 error");
        }

        // --- Multi-level LR (precedence grammar) ---
        private static final String PRECEDENCE_LR_REEXPAND = """
            E <- E "+" T / T ;
            T <- T "*" F / F ;
            F <- "(" E ")" / "n" ;
            """;

        @Test
        void testF1LR05MultilevelAtT() {
            // Error at T level requires both E and T to re-expand
            var r = TestUtils.testParse(PRECEDENCE_LR_REEXPAND, "n+n*Xn", "E");
            assertTrue(r.ok(), "multi-level LR must re-expand correctly");
            assertTrue(r.errorCount() >= 1, "should have at least 1 error");
            assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("X")), "should skip X");
        }

        @Test
        void testF1LR06MultilevelAtE() {
            // Error at E level
            var r = TestUtils.testParse(PRECEDENCE_LR_REEXPAND, "n+Xn*n", "E");
            assertTrue(r.ok(), "should recover at E level");
            assertTrue(r.errorCount() >= 1, "should have at least 1 error");
        }

        @Test
        void testF1LR07MultilevelNestedParens() {
            // Error inside parentheses
            var r = TestUtils.testParse(PRECEDENCE_LR_REEXPAND, "n+(nX*n)", "E");
            assertTrue(r.ok(), "should recover inside parens");
        }

        // --- LR with probe() interaction ---
        private static final String LR_PROBE_GRAMMAR = """
            S <- E+ "z" ;
            E <- E "x" / "a" ;
            """;

        @Test
        void testF2LR01ProbeDuringExpansion() {
            // Repetition probes LR rule E for bounds checking
            var r = TestUtils.testParse(LR_PROBE_GRAMMAR, "axaXz");
            assertTrue(r.ok(), "probe of LR during Phase 2 should work");
            assertEquals(1, r.errorCount(), "should have 1 error");
        }

        @Test
        void testF2LR02ProbeMultipleLR() {
            var r = TestUtils.testParse(LR_PROBE_GRAMMAR, "axaxXz");
            assertTrue(r.ok(), "should handle multiple LR matches before error");
        }
    }

    // ===========================================================================
    // recoveryVersion NECESSITY TESTS
    // ===========================================================================

    @Nested
    class RecoveryVersionNecessityTests {
        // --- Distinguish Phase 1 (v=0,e=false) from probe() in Phase 2 (v=1,e=false) ---
        // NOTE: Grammar designed so A* and B don't compete for the same characters.
        // A matches 'a', B matches 'bz'. This way skipping X and matching 'abz' works.
        private static final String RECOVERY_VERSION_GRAMMAR = """
            S <- A* B ;
            A <- "a" ;
            B <- "b" "z" ;
            """;

        @Test
        void testF3RV01Phase1VsProbe() {
            // Phase 1: A* matches empty at 0 (mismatch on 'X'). B fails.
            // Phase 2: skip X, A* matches 'a', B matches 'bz'.
            var r = TestUtils.testParse(RECOVERY_VERSION_GRAMMAR, "Xabz");
            assertTrue(r.ok(), "should skip X and match abz");
            assertEquals(1, r.errorCount(), "should have 1 error");
            assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("X")), "should skip X");
        }

        @Test
        void testF3RV02CachedMismatchReuse() {
            // Mismatch cached in Phase 1 should not poison probe() in Phase 2
            String mismatchGrammar = """
                S <- A* B "!" ;
                A <- "a" ;
                B <- "bbb" ;
                """;
            var r = TestUtils.testParse(mismatchGrammar, "aaXbbb!");
            assertTrue(r.ok(), "mismatch from Phase 1 should not block Phase 2 probe");
        }

        @Test
        void testF3RV03IncompleteDifferentVersions() {
            // Incomplete result at (v=0,e=false) vs query at (v=1,e=false)
            String incompleteGrammar = """
                S <- A? B ;
                A <- "aaa" ;
                B <- "a" "z" ;
                """;
            // Phase 1: A? returns incomplete empty (can't match 'X')
            // Phase 2 probe: should recompute, not reuse Phase 1's incomplete
            var r = TestUtils.testParse(incompleteGrammar, "Xaz");
            assertTrue(r.ok(), "should recover despite incomplete from Phase 1");
        }
    }

    // ===========================================================================
    // DEEP INTERACTION TESTS
    // ===========================================================================

    @Nested
    class DeepInteractionTests {
        // --- LR + bounded repetition + recovery ---
        private static final String DEEP_INTERACTION_GRAMMAR = """
            S <- E ";" ;
            E <- E "+" T / T ;
            T <- F+ ;
            F <- "n" / "(" E ")" ;
            """;

        @Test
        void testDeep01LRBoundedRecovery() {
            // LR at E level, bounded rep at T level, recovery needed
            var r = TestUtils.testParse(DEEP_INTERACTION_GRAMMAR, "n+nnXn;");
            assertTrue(r.ok(), "should recover in bounded rep under LR");
        }

        @Test
        void testDeep02NestedLRRecovery() {
            // Recovery inside parenthesized expression under LR
            var r = TestUtils.testParse(DEEP_INTERACTION_GRAMMAR, "n+(nXn);");
            assertTrue(r.ok(), "should recover inside nested structure");
        }

        @Test
        void testDeep03MultipleLevels() {
            // Errors at multiple structural levels
            var r = TestUtils.testParse(DEEP_INTERACTION_GRAMMAR, "nXn+nYn;");
            assertTrue(r.ok(), "should handle errors at multiple levels");
            assertTrue(r.errorCount() >= 2, "should have at least 2 errors");
        }
    }
}
