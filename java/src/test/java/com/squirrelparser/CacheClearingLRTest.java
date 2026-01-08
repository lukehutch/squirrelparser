package com.squirrelparser;

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
import com.squirrelparser.Combinators.ZeroOrMore;
import com.squirrelparser.Terminals.Str;

/**
 * CACHE CLEARING BUG TESTS (Document 4 fix) and LR RE-EXPANSION TESTS
 * Port of cache_clearing_lr_test.dart
 */
class CacheClearingLRTest {

    // ===========================================================================
    // CACHE CLEARING BUG TESTS (Document 4 fix)
    // ===========================================================================

    // --- Non-LR incomplete result must be cleared when recovery state changes ---
    // Bug: foundLeftRec && condition prevents clearing non-LR incomplete results

    private static final Map<String, Clause> staleClearGrammar = Map.of(
        "S", new Seq(new OneOrMore(new Ref("A")), new Str("z")),
        "A", new First(new Str("ab"), new Str("a"))
    );

    @Test
    void testF4_01_staleNonLRIncomplete() {
        // Phase 1: A+ matches 'a' at 0, fails at 'X'. Incomplete, len=1.
        // Phase 2: A+ should skip 'X', match 'ab', get len=4
        // Bug: stale len=1 result returned without clearing
        var r = parse(staleClearGrammar, "aXabz");
        assertTrue(r.success(), "should recover by skipping X");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skipped().stream().anyMatch(s -> s.contains("X")), "should skip X");
    }

    @Test
    void testF4_02_staleNonLRIncompleteMulti() {
        // Multiple recovery points in non-LR repetition
        var r = parse(staleClearGrammar, "aXaYabz");
        assertTrue(r.success(), "should recover from multiple errors");
        assertEquals(2, r.errorCount(), "should have 2 errors");
    }

    // --- probe() during Phase 2 must get fresh results ---
    private static final Map<String, Clause> probeContextGrammar = Map.of(
        "S", new Seq(new Ref("A"), new Ref("B")),
        "A", new OneOrMore(new Str("a")),
        "B", new Seq(new ZeroOrMore(new Str("a")), new Str("z"))
    );

    @Test
    void testF4_03_probeContextPhase2() {
        // Bounded repetition uses probe() to check if B can match
        // probe() must not reuse stale Phase 2 results
        var r = parse(probeContextGrammar, "aaaXz");
        assertTrue(r.success(), "should recover");
        assertEquals(1, r.errorCount(), "should have 1 error");
    }

    @Test
    void testF4_04_probeAtBoundary() {
        // Edge case: probe at exact boundary between clauses
        var r = parse(probeContextGrammar, "aXaz");
        assertTrue(r.success(), "should recover at boundary");
    }

    // ===========================================================================
    // LR RE-EXPANSION TESTS (Complete LR + recovery context change)
    // ===========================================================================

    // --- Direct LR must re-expand in Phase 2 ---
    // NOTE: Using Seq([Str('+'), Str('n')]) instead of Str('+n') to allow
    // recovery to skip characters between '+' and 'n'.
    private static final Map<String, Clause> directLRReexpand = Map.of(
        "E", new First(
            new Seq(new Ref("E"), new Str("+"), new Str("n")),
            new Str("n")
        )
    );

    @Test
    void testF1_LR_01_reexpandSimple() {
        // Phase 1: E matches 'n' (len=1), complete
        // Phase 2: must re-expand to skip 'X' and get 'n+n+n' (len=6)
        var r = parse(directLRReexpand, "n+Xn+n", "E");
        assertTrue(r.success(), "LR must re-expand in Phase 2");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skipped().stream().anyMatch(s -> s.contains("X")), "should skip X");
    }

    @Test
    void testF1_LR_02_reexpandMultipleErrors() {
        // Multiple errors in LR expansion
        var r = parse(directLRReexpand, "n+Xn+Yn+n", "E");
        assertTrue(r.success(), "LR should handle multiple errors");
        assertEquals(2, r.errorCount(), "should have 2 errors");
    }

    @Test
    void testF1_LR_03_reexpandAtStart() {
        // Error between base 'n' and '+' - recovery should skip X
        var r = parse(directLRReexpand, "nX+n+n", "E");
        assertTrue(r.success(), "should recover by skipping X");
        assertEquals(1, r.errorCount(), "should have 1 error");
    }

    // --- Indirect LR re-expansion ---
    private static final Map<String, Clause> indirectLRReexpand = Map.of(
        "E", new First(new Ref("F"), new Str("n")),
        "F", new Seq(new Ref("E"), new Str("+"), new Str("n"))
    );

    @Test
    void testF1_LR_04_indirectReexpand() {
        var r = parse(indirectLRReexpand, "n+Xn+n", "E");
        assertTrue(r.success(), "indirect LR must re-expand");
        assertEquals(1, r.errorCount(), "should have 1 error");
    }

    // --- Multi-level LR (precedence grammar) ---
    private static final Map<String, Clause> precedenceLRReexpand = Map.of(
        "E", new First(
            new Seq(new Ref("E"), new Str("+"), new Ref("T")),
            new Ref("T")
        ),
        "T", new First(
            new Seq(new Ref("T"), new Str("*"), new Ref("F")),
            new Ref("F")
        ),
        "F", new First(
            new Seq(new Str("("), new Ref("E"), new Str(")")),
            new Str("n")
        )
    );

    @Test
    void testF1_LR_05_multilevelAtT() {
        // Error at T level requires both E and T to re-expand
        var r = parse(precedenceLRReexpand, "n+n*Xn", "E");
        assertTrue(r.success(), "multi-level LR must re-expand correctly");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
        assertTrue(r.skipped().stream().anyMatch(s -> s.contains("X")), "should skip X");
    }

    @Test
    void testF1_LR_06_multilevelAtE() {
        // Error at E level
        var r = parse(precedenceLRReexpand, "n+Xn*n", "E");
        assertTrue(r.success(), "should recover at E level");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
    }

    @Test
    void testF1_LR_07_multilevelNestedParens() {
        // Error inside parentheses
        var r = parse(precedenceLRReexpand, "n+(nX*n)", "E");
        assertTrue(r.success(), "should recover inside parens");
    }

    // --- LR with probe() interaction ---
    private static final Map<String, Clause> lrProbeGrammar = Map.of(
        "S", new Seq(new OneOrMore(new Ref("E")), new Str("z")),
        "E", new First(
            new Seq(new Ref("E"), new Str("x")),
            new Str("a")
        )
    );

    @Test
    void testF2_LR_01_probeDuringExpansion() {
        // Repetition probes LR rule E for bounds checking
        var r = parse(lrProbeGrammar, "axaXz");
        assertTrue(r.success(), "probe of LR during Phase 2 should work");
        assertEquals(1, r.errorCount(), "should have 1 error");
    }

    @Test
    void testF2_LR_02_probeMultipleLR() {
        var r = parse(lrProbeGrammar, "axaxXz");
        assertTrue(r.success(), "should handle multiple LR matches before error");
    }

    // ===========================================================================
    // recoveryVersion NECESSITY TESTS
    // ===========================================================================

    // --- Distinguish Phase 1 (v=0,e=false) from probe() in Phase 2 (v=1,e=false) ---
    // NOTE: Grammar designed so A* and B don't compete for the same characters.
    // A matches 'a', B matches 'bz'. This way skipping X and matching 'abz' works.
    private static final Map<String, Clause> recoveryVersionGrammar = Map.of(
        "S", new Seq(new ZeroOrMore(new Ref("A")), new Ref("B")),
        "A", new Str("a"),
        "B", new Seq(new Str("b"), new Str("z"))
    );

    @Test
    void testF3_RV_01_phase1VsProbe() {
        // Phase 1: A* matches empty at 0 (mismatch on 'X'). B fails.
        // Phase 2: skip X, A* matches 'a', B matches 'bz'.
        var r = parse(recoveryVersionGrammar, "Xabz");
        assertTrue(r.success(), "should skip X and match abz");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skipped().stream().anyMatch(s -> s.contains("X")), "should skip X");
    }

    @Test
    void testF3_RV_02_cachedMismatchReuse() {
        // Mismatch cached in Phase 1 should not poison probe() in Phase 2
        Map<String, Clause> mismatchGrammar = Map.of(
            "S", new Seq(new ZeroOrMore(new Ref("A")), new Ref("B"), new Str("!")),
            "A", (Clause) new Str("a"),
            "B", (Clause) new Str("bbb")
        );
        var r = parse(mismatchGrammar, "aaXbbb!");
        assertTrue(r.success(), "mismatch from Phase 1 should not block Phase 2 probe");
    }

    @Test
    void testF3_RV_03_incompleteDifferentVersions() {
        // Incomplete result at (v=0,e=false) vs query at (v=1,e=false)
        Map<String, Clause> incompleteGrammar = Map.of(
            "S", new Seq(new Optional(new Ref("A")), new Ref("B")),
            "A", (Clause) new Str("aaa"),
            "B", new Seq(new Str("a"), new Str("z"))
        );
        // Phase 1: A? returns incomplete empty (can't match 'X')
        // Phase 2 probe: should recompute, not reuse Phase 1's incomplete
        var r = parse(incompleteGrammar, "Xaz");
        assertTrue(r.success(), "should recover despite incomplete from Phase 1");
    }

    // ===========================================================================
    // DEEP INTERACTION TESTS
    // ===========================================================================

    // --- LR + bounded repetition + recovery ---
    private static final Map<String, Clause> deepInteractionGrammar = Map.of(
        "S", new Seq(new Ref("E"), new Str(";")),
        "E", new First(
            new Seq(new Ref("E"), new Str("+"), new Ref("T")),
            new Ref("T")
        ),
        "T", new OneOrMore(new Ref("F")),
        "F", new First(
            new Str("n"),
            new Seq(new Str("("), new Ref("E"), new Str(")"))
        )
    );

    @Test
    void testDEEP_01_LRBoundedRecovery() {
        // LR at E level, bounded rep at T level, recovery needed
        var r = parse(deepInteractionGrammar, "n+nnXn;");
        assertTrue(r.success(), "should recover in bounded rep under LR");
    }

    @Test
    void testDEEP_02_nestedLRRecovery() {
        // Recovery inside parenthesized expression under LR
        var r = parse(deepInteractionGrammar, "n+(nXn);");
        assertTrue(r.success(), "should recover inside nested structure");
    }

    @Test
    void testDEEP_03_multipleLevels() {
        // Errors at multiple structural levels
        var r = parse(deepInteractionGrammar, "nXn+nYn;");
        assertTrue(r.success(), "should handle errors at multiple levels");
        assertTrue(r.errorCount() >= 2, "should have at least 2 errors");
    }
}
