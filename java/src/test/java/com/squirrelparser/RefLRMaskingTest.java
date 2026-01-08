package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.Str;

/**
 * REF LR MASKING TESTS (9 tests)
 * Port of ref_lr_masking_test.dart
 *
 * Tests for multi-level left recursion with error recovery.
 *
 * KNOWN LIMITATION:
 * In multi-level LR grammars like E -> E+T | T and T -> T*F | F:
 * - When parsing "n+n*Xn", error is at '*Xn' where 'X' should be skipped
 * - Optimal: T*F recovers by skipping 'X' -> 1 error
 * - Current: E+T recovers by skipping '*X' -> 2 errors
 *
 * ROOT CAUSE:
 * Ref('T') at position 2 creates a separate MemoEntry from the inner T rule.
 * During Phase 2, E re-expands (foundLeftRec=true), but Ref('T') doesn't
 * because its MemoEntry.foundLeftRec=false (doesn't inherit from inner T).
 * This means T@2 returns cached result without trying recovery at T*F level.
 */
class RefLRMaskingTest {

    // Standard precedence grammar with multi-level left recursion
    private static final Map<String, Clause> precedenceGrammar = Map.of(
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
    void testMULTILR01ErrorAtFLevelAfterStar() {
        var r = parse(precedenceGrammar, "n+n*Xn", "E");
        assertTrue(r.success(), "should parse with recovery");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
    }

    @Test
    void testMULTILR02ErrorAtTLevelAfterPlus() {
        var r = parse(precedenceGrammar, "n+Xn*n", "E");
        assertTrue(r.success(), "should parse with recovery");
        assertTrue(r.errorCount() >= 1, "should have at least 1 error");
    }

    @Test
    void testMULTILR03NestedErrorInParens() {
        var r = parse(precedenceGrammar, "n+(n*Xn)", "E");
        assertTrue(r.success(), "should recover inside parens");
        assertTrue(r.errorCount() >= 1, "should have errors");
    }

    // Simpler two-level grammar to isolate the issue
    private static final Map<String, Clause> twoLevelGrammar = Map.of(
        "A", new First(
            new Seq(new Ref("A"), new Str("+"), new Ref("B")),
            new Ref("B")
        ),
        "B", new First(
            new Seq(new Ref("B"), new Str("-"), new Str("x")),
            new Str("x")
        )
    );

    @Test
    void testMULTILR04TwoLevel() {
        var r = parse(twoLevelGrammar, "x+x-Yx", "A");
        assertTrue(r.success(), "should parse with recovery");
        assertTrue(r.errorCount() >= 1, "should have errors");
    }

    @Test
    void testMULTILR05ThreeLevels() {
        Map<String, Clause> threeLevelGrammar = Map.of(
            "A", new First(
                new Seq(new Ref("A"), new Str("+"), new Ref("B")),
                new Ref("B")
            ),
            "B", new First(
                new Seq(new Ref("B"), new Str("*"), new Ref("C")),
                new Ref("C")
            ),
            "C", new First(
                new Seq(new Ref("C"), new Str("-"), new Str("x")),
                new Str("x")
            )
        );
        var r = parse(threeLevelGrammar, "x+x*x-Yx", "A");
        assertTrue(r.success(), "should parse with recovery");
        assertTrue(r.errorCount() >= 1, "should have errors");
    }

    // Single-level LR works correctly with exact error counts
    @Test
    void testSINGLELR01Basic() {
        Map<String, Clause> grammar = Map.of(
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            )
        );
        var r = parse(grammar, "n+Xn", "E");
        assertTrue(r.success(), "basic LR recovery should work");
        assertEquals(1, r.errorCount(), "single-level LR should have exact error count");
    }

    @Test
    void testSINGLELR02MultipleExpansions() {
        Map<String, Clause> grammar = Map.of(
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            )
        );
        var r = parse(grammar, "n+Xn+n", "E");
        assertTrue(r.success());
        assertEquals(1, r.errorCount(), "single-level LR should skip exactly X");
    }

    @Test
    void testSINGLELR03MultipleErrors() {
        Map<String, Clause> grammar = Map.of(
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            )
        );
        var r = parse(grammar, "n+Xn+Yn", "E");
        assertTrue(r.success());
        assertEquals(2, r.errorCount(), "should have 2 errors");
    }

    // LR_PENDING Fix Verification
    @Test
    void testLRPENDING01NoSpuriousRecovery() {
        Map<String, Clause> grammar = Map.of(
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Ref("T")),
                new Ref("T")
            ),
            "T", new First(
                new Seq(new Ref("T"), new Str("*"), new Str("n")),
                new Str("n")
            )
        );
        var r = parse(grammar, "n+n*Xn", "E");
        assertTrue(r.success());
        assertTrue(r.errorCount() <= 3, "LR_PENDING should prevent excessive errors");
    }
}
