package com.squirrelparser;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.util.stream.Collectors;
import java.util.stream.IntStream;

import static com.squirrelparser.TestUtils.*;
import static org.junit.jupiter.api.Assertions.*;

/**
 * ADVANCED STRESS TESTS FOR SQUIRREL PARSER RECOVERY
 *
 * These tests attempt to expose edge cases, subtle bugs, and potential
 * violations of the three invariants (Completeness, Isolation, Minimality).
 */
class AdvancedStressTest {

    // ===========================================================================
    // SECTION A: PHASE ISOLATION ATTACKS
    // ===========================================================================

    @Nested
    class PhaseIsolationAttacks {
        @Test
        void testISO01_ProbeDuringRecoveryProbe() {
            String grammar = """
                S <- A* B ;
                A <- "a"+ "x" ;
                B <- "b" "z" ;
                """;
            ParseTestResult r = testParse(grammar, "aaXxbz");
            assertTrue(r.ok(), "nested probe should not poison cache");
        }

        @Test
        void testISO02_RecoveryVersionOverflow() {
            String grammar = "S <- \"ab\"+ ;";
            String input = "ab" + IntStream.range(0, 50).mapToObj(i -> "Xab").collect(Collectors.joining());
            ParseTestResult r = testParse(grammar, input);
            assertTrue(r.ok(), "many errors should not overflow version");
            assertEquals(50, r.errorCount(), "should count all 50 errors");
        }

        @Test
        void testISO03_AlternatingProbeMatch() {
            String grammar = """
                S <- A* B* "end" ;
                A <- "a" ;
                B <- "a" ;
                """;
            ParseTestResult r = testParse(grammar, "aaaXend");
            assertTrue(r.ok(), "ambiguous probes should resolve correctly");
        }

        @Test
        void testISO04_CompleteResultReuseAfterLR() {
            String grammar = """
                S <- A E ;
                A <- "a" ;
                E <- E "+" "a" / "a" ;
                """;
            ParseTestResult r = testParse(grammar, "aa+a");
            assertTrue(r.ok(), "complete result should be isolated from LR");
            assertEquals(0, r.errorCount(), "clean parse");
        }

        @Test
        void testISO05_MismatchCacheAcrossPhases() {
            String grammar = """
                S <- "abc" "xyz" / "ab" "z" ;
                """;
            ParseTestResult r = testParse(grammar, "abXz");
            assertTrue(r.ok(), "Phase 1 mismatch should not block Phase 2");
        }
    }

    // ===========================================================================
    // SECTION B: LEFT RECURSION EDGE CASES
    // ===========================================================================

    @Nested
    class LeftRecursionEdgeCases {
        @Test
        void testLREdge01_TripleNestedLR() {
            String grammar = """
                A <- A "+" B / B ;
                B <- B "*" C / C ;
                C <- C "-" "n" / "n" ;
                """;
            ParseTestResult r = testParse(grammar, "n+n*n-Xn", "A");
            assertTrue(r.ok(), "triple LR should recover");
        }

        @Test
        void testLREdge02_LRInsideRepetition() {
            String grammar = """
                S <- E+ ;
                E <- E "+" "n" / "n" ;
                """;
            ParseTestResult r = testParse(grammar, "n+nXn+n");
            assertTrue(r.ok(), "LR inside repetition should work");
        }

        @Test
        void testLREdge03_LRWithLookahead() {
            String grammar = """
                E <- E "+" T / T ;
                T <- !"+" "n" ;
                """;
            ParseTestResult r = testParse(grammar, "n+Xn", "E");
            assertTrue(r.ok(), "LR with lookahead should recover");
        }

        @Test
        void testLREdge04_MutualLR() {
            String grammar = """
                A <- B "a" / "x" ;
                B <- A "b" / "y" ;
                """;
            ParseTestResult r = testParse(grammar, "ybaXba", "A");
            assertTrue(r.ok(), "mutual LR should recover");
        }

        @Test
        void testLREdge05_LRZeroLengthBetween() {
            String grammar = """
                E <- E " "? "+" "n" / "n" ;
                """;
            ParseTestResult r = testParse(grammar, "n +Xn", "E");
            assertTrue(r.ok(), "LR with optional should recover");
        }

        @Test
        void testLREdge06_LREmptyBase() {
            String grammar = """
                E <- E "+" "n" / "n"? ;
                """;
            // This is a pathological grammar - empty base allows infinite LR
            // Parser should handle gracefully
            testParse(grammar, "+n+n", "E");
            // May fail or succeed with errors - just shouldn't infinite loop
            assertTrue(true, "should not infinite loop");
        }
    }

    // ===========================================================================
    // SECTION C: RECOVERY MINIMALITY ATTACKS
    // ===========================================================================

    @Nested
    class RecoveryMinimalityAttacks {
        @Test
        void testMIN01_MultipleValidRecoveries() {
            String grammar = """
                S <- "a" "b" "c" / "a" "c" ;
                """;
            ParseTestResult r = testParse(grammar, "aXc");
            assertTrue(r.ok(), "should find recovery");
            assertEquals(1, r.errorCount(), "should choose minimal recovery");
        }

        @Test
        void testMIN02_GrammarDeletionVsInputSkip() {
            String grammar = "S <- \"a\" \"b\" \"c\" \"d\" ;";
            ParseTestResult r = testParse(grammar, "aXd");
            assertFalse(r.ok(), "should fail (requires mid-parse grammar deletion)");

            ParseTestResult r2 = testParse(grammar, "abc");
            assertTrue(r2.ok(), "should succeed with EOF grammar deletion");
            assertEquals(1, r2.errorCount(), "delete \"d\" at EOF");
        }

        @Test
        void testMIN03_GreedyRepetitionInteraction() {
            String grammar = "S <- \"a\"+ \"b\" ;";
            ParseTestResult r = testParse(grammar, "aaaaXb");
            assertTrue(r.ok(), "repetition should respect bounds");
            assertEquals(1, r.errorCount(), "should skip only X");
        }

        @Test
        void testMIN04_NestedSeqRecovery() {
            String grammar = """
                S <- "(" ("a" "b") ")" ;
                """;
            ParseTestResult r = testParse(grammar, "(aXb)");
            assertTrue(r.ok(), "inner Seq should recover by skipping X");
            assertEquals(1, r.errorCount(), "should skip only X");

            ParseTestResult r2 = testParse(grammar, "(aX)");
            assertFalse(r2.ok(), "should fail (requires mid-parse grammar deletion)");
        }

        @Test
        void testMIN05_RecoveryPositionOptimization() {
            String grammar = "S <- \"aaa\" \"bbb\" ;";
            ParseTestResult r = testParse(grammar, "aaXbbb");
            assertFalse(r.ok(), "should fail (requires mid-parse grammar deletion)");
        }
    }

    // ===========================================================================
    // SECTION D: COMPLETENESS ACCURACY ATTACKS
    // ===========================================================================

    @Nested
    class CompletenessAccuracyAttacks {
        @Test
        void testCOMP01_NestedIncomplete() {
            String grammar = """
                S <- A "z" ;
                A <- B "y" ;
                B <- C "x" ;
                C <- "a"* ;
                """;
            ParseTestResult r = testParse(grammar, "aaaQxyz");
            assertTrue(r.ok(), "deeply nested incomplete should trigger recovery");
            assertEquals(1, r.errorCount(), "should skip Q");
        }

        @Test
        void testCOMP02_OptionalInsideRepetition() {
            String grammar = """
                S <- ("a" "b"?)+ "z" ;
                """;
            ParseTestResult r = testParse(grammar, "aabXaz");
            assertTrue(r.ok(), "should recover");
        }

        @Test
        void testCOMP03_FirstAlternativeIncomplete() {
            String grammar = """
                S <- "a"* "x" / "a"* "y" ;
                """;
            ParseTestResult r = testParse(grammar, "aaaQy");
            assertTrue(r.ok(), "should recover");
        }

        @Test
        void testCOMP04_CompleteZeroLength() {
            String grammar = "S <- \"x\"* \"a\" ;";
            ParseTestResult r = testParse(grammar, "a");
            assertTrue(r.ok(), "zero-length complete should work");
            assertEquals(0, r.errorCount(), "clean parse");
        }

        @Test
        void testCOMP05_IncompleteAtEOF() {
            String grammar = "S <- \"a\"+ \"z\" ;";
            ParseTestResult r = testParse(grammar, "aaa");
            assertTrue(r.ok(), "should delete missing z");
        }
    }

    // ===========================================================================
    // SECTION E: CACHE COHERENCE STRESS TESTS
    // ===========================================================================

    @Nested
    class CacheCoherenceStressTests {
        @Test
        void testCACHE01_SameClauseMultiplePositions() {
            String grammar = """
                S <- X "+" X ;
                X <- "n" ;
                """;
            ParseTestResult r = testParse(grammar, "nQn");
            assertFalse(r.ok(), "requires mid-parse grammar deletion");

            ParseTestResult r2 = testParse(grammar, "n+Xn");
            assertTrue(r2.ok(), "same clause at different positions");
            assertEquals(1, r2.errorCount(), "skip X between + and n");
        }

        @Test
        void testCACHE02_DiamondDependency() {
            String grammar = """
                S <- A B ;
                A <- "a" C ;
                B <- "b" C ;
                C <- "c" ;
                """;
            ParseTestResult r = testParse(grammar, "acXbc");
            assertTrue(r.ok(), "diamond dependency should work");
        }

        @Test
        void testCACHE03_RepeatedLRAtSamePos() {
            String grammar = """
                S <- E ";" E ;
                E <- E "+" "n" / "n" ;
                """;
            ParseTestResult r = testParse(grammar, "n+n;n+Xn");
            assertTrue(r.ok(), "repeated LR should work");
        }

        @Test
        void testCACHE04_InterleavedLRAndNonLR() {
            String grammar = """
                S <- E "," F "," E ;
                E <- E "+" "n" / "n" ;
                F <- "xyz" ;
                """;
            ParseTestResult r = testParse(grammar, "n+n,xyz,n+Xn");
            assertTrue(r.ok(), "interleaved LR/non-LR should work");
        }

        @Test
        void testCACHE05_RapidPhaseSwitching() {
            String grammar = """
                S <- A* B* C* "end" ;
                A <- "a" ;
                B <- "b" ;
                C <- "c" ;
                """;
            ParseTestResult r = testParse(grammar, "aaaXbbbYcccZend");
            assertTrue(r.ok(), "rapid phase switching should work");
        }
    }

    // ===========================================================================
    // SECTION F: PATHOLOGICAL GRAMMARS
    // ===========================================================================

    @Nested
    class PathologicalGrammars {
        private String buildDeepFirst(int depth) {
            if (depth == 0) return "\"target\"";
            return "\"x\" / (" + buildDeepFirst(depth - 1) + ")";
        }

        @Test
        void testPATH01_DeeplyNestedFirst() {
            String grammar = "S <- " + buildDeepFirst(20) + " ;";
            ParseTestResult r = testParse(grammar, "target");
            assertTrue(r.ok(), "deep First should work");
        }

        private String buildDeepSeq(int depth) {
            if (depth == 0) return "\"x\"";
            return "\"a\" (" + buildDeepSeq(depth - 1) + ")";
        }

        @Test
        void testPATH02_DeeplyNestedSeq() {
            String grammar = "S <- (" + buildDeepSeq(20) + ") \"end\" ;";
            String input = "a".repeat(20) + "Qx" + "end";
            ParseTestResult r = testParse(grammar, input);
            assertTrue(r.ok(), "deep Seq should recover");
        }

        @Test
        void testPATH03_ManyAlternatives() {
            String alts = IntStream.range(0, 50)
                .mapToObj(i -> "\"opt" + i + "\"")
                .collect(Collectors.joining(" / "));
            String grammar = "S <- " + alts + " / \"target\" ;";
            ParseTestResult r = testParse(grammar, "target");
            assertTrue(r.ok(), "many alternatives should work");
        }

        @Test
        void testPATH04_WideSeq() {
            String elems = IntStream.range(0, 30)
                .mapToObj(i -> "\"" + (char)('a' + (i % 26)) + "\"")
                .collect(Collectors.joining(" "));
            String grammar = "S <- " + elems + " ;";
            String input = IntStream.range(0, 30)
                .mapToObj(i -> String.valueOf((char)('a' + (i % 26))))
                .collect(Collectors.joining());
            String errInput = input.substring(0, 15) + "X" + input.substring(15);
            ParseTestResult r = testParse(grammar, errInput);
            assertTrue(r.ok(), "wide Seq should recover");
        }

        @Test
        void testPATH05_RepetitionOfRepetition() {
            String grammar = "S <- (\"a\"+)+ ;";
            ParseTestResult r = testParse(grammar, "aaaXaaa");
            assertTrue(r.ok(), "nested repetition should work");
        }
    }

    // ===========================================================================
    // SECTION G: REAL-WORLD GRAMMAR PATTERNS
    // ===========================================================================

    @Nested
    class RealWorldGrammarPatterns {
        @Test
        void testREAL01_JsonLikeArray() {
            String grammar = """
                Array <- "[" Elements? "]" ;
                Elements <- Value ("," Value)* ;
                Value <- Array / "n" ;
                """;
            ParseTestResult r = testParse(grammar, "[n n]", "Array");
            assertTrue(r.ok(), "should recover missing comma");
        }

        @Test
        void testREAL02_ExpressionWithParens() {
            String grammar = """
                E <- E "+" T / T ;
                T <- T "*" F / F ;
                F <- "(" E ")" / "n" ;
                """;
            ParseTestResult r = testParse(grammar, "(n+n", "E");
            assertTrue(r.ok(), "should insert missing close paren");
        }

        @Test
        void testREAL03_StatementList() {
            String grammar = """
                Program <- Stmt+ ;
                Stmt <- Expr ";" ;
                Expr <- "if" "(" Expr ")" Stmt / "x" ;
                """;
            ParseTestResult r = testParse(grammar, "x x;", "Program");
            assertTrue(r.ok(), "should recover missing semicolon");
        }

        @Test
        void testREAL04_StringLiteral() {
            String grammar = "S <- \"\\\"\" [a-z]* \"\\\"\" ;";
            ParseTestResult r = testParse(grammar, "\"hello");
            assertTrue(r.ok(), "should insert missing quote");
        }

        @Test
        void testREAL05_NestedBlocks() {
            String grammar = """
                Block <- "{" Stmt* "}" ;
                Stmt <- Block / "x" ";" ;
                """;
            ParseTestResult r = testParse(grammar, "{x;{x;Xx;}}", "Block");
            assertTrue(r.ok(), "nested blocks should recover");
        }
    }

    // ===========================================================================
    // SECTION H: EMERGENT INTERACTION TESTS
    // ===========================================================================

    @Nested
    class EmergentInteractionTests {
        @Test
        void testEMERG01_LRWithBoundedRepRecovery() {
            String grammar = """
                S <- E "end" ;
                E <- E "+" "n"+ / "n" ;
                """;
            ParseTestResult r = testParse(grammar, "n+nXn+nnend");
            assertTrue(r.ok(), "LR with bounded rep should work");
        }

        @Test
        void testEMERG02_ProbeTriggersLR() {
            String grammar = """
                S <- "a"* E ;
                E <- E "+" "n" / "n" ;
                """;
            ParseTestResult r = testParse(grammar, "aaXn+n");
            assertTrue(r.ok(), "probe triggering LR should work");
        }

        @Test
        void testEMERG03_RecoveryResetsLRExpansion() {
            String grammar = """
                S <- E ";" E ;
                E <- E "+" "n" / "n" ;
                """;
            ParseTestResult r = testParse(grammar, "n+Xn;n+n+n");
            assertTrue(r.ok(), "second LR should expand independently");
            assertEquals(1, r.errorCount(), "only first E has error");
        }

        @Test
        void testEMERG04_IncompletePropagationThroughLR() {
            String grammar = """
                E <- E "+" T / T ;
                T <- "n" "x"* ;
                """;
            ParseTestResult r = testParse(grammar, "nxx+nxQx", "E");
            assertTrue(r.ok(), "incomplete should propagate through LR");
        }

        @Test
        void testEMERG05_CacheVersionAfterLRRecovery() {
            String grammar = """
                S <- E ";" E ;
                E <- E "+" "n" / "n" ;
                """;
            ParseTestResult r = testParse(grammar, "n+Xn+n;n+n");
            assertTrue(r.ok(), "version should be correct after LR recovery");
        }
    }
}
