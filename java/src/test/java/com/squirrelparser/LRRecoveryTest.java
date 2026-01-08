package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.Str;

/**
 * SECTION 13: LEFT RECURSION ERROR RECOVERY
 * Port of lr_recovery_test.dart
 */
class LRRecoveryTest {

    // directLR grammar for error recovery tests
    private static final Map<String, Clause> directLR = Map.of(
        "S", new Ref("E"),
        "E", new First(
            new Seq(new Ref("E"), new Str("+n")),
            new Str("n")
        )
    );

    // precedenceLR grammar for error recovery tests
    private static final Map<String, Clause> precedenceLR = Map.of(
        "S", new Ref("E"),
        "E", new First(
            new Seq(new Ref("E"), new Str("+"), new Ref("T")),
            new Seq(new Ref("E"), new Str("-"), new Ref("T")),
            new Ref("T")
        ),
        "T", new First(
            new Seq(new Ref("T"), new Str("*"), new Ref("F")),
            new Seq(new Ref("T"), new Str("/"), new Ref("F")),
            new Ref("F")
        ),
        "F", new First(
            new Seq(new Str("("), new Ref("E"), new Str(")")),
            new Str("n")
        )
    );

    // Error recovery in direct LR grammar
    @Test
    void testLRRecovery01_leadingError() {
        // Input '+n+n+n+' starts with '+' which is invalid (need 'n' first)
        // and ends with '+' which is also invalid (need 'n' after)
        var result = parse(directLR, "+n+n+n+");
        // This should fail because we can't recover a valid parse
        // The leading '+' prevents any initial 'n' match
        assertFalse(result.success(), "should fail (leading + is unrecoverable)");
    }

    @Test
    void testLRRecovery02_internalError() {
        // Input 'n+Xn+n' has garbage 'X' between + and n
        var result = parse(directLR, "n+Xn+n");
        // After 'n+', we expect 'n' but get 'X'. Recovery should skip 'X'.
        // But actually '+n' is the terminal, so 'n+X' doesn't match '+n'
        // This should fail since we can't parse 'n+X...'
        assertFalse(result.success(), "should fail (X breaks +n terminal)");
    }

    @Test
    void testLRRecovery03_trailingJunk() {
        // Input 'n+n+nXXX' has trailing garbage
        var result = parse(directLR, "n+n+nXXX");
        // After parsing 'n+n+n', there's trailing 'XXX' that can't be consumed
        assertFalse(result.success(), "should fail (trailing garbage)");
    }

    // Error recovery in precedence grammar
    @Test
    void testLRRecovery04_missingOperand() {
        // Input 'n+*n' has missing operand between + and *
        // Parser recovers by skipping the extra '+' to parse as 'n*n'
        var result = parse(precedenceLR, "n+*n");
        assertTrue(result.success(), "should recover by skipping +");
        assertEquals(1, result.errorCount(), "one error: skip +");
        assertTrue(result.skipped().contains("+"));
    }

    @Test
    void testLRRecovery05_doubleOp() {
        // Input 'n++n' has double operator
        // Parser recovers by skipping the extra '+' to parse as 'n+n'
        var result = parse(precedenceLR, "n++n");
        assertTrue(result.success(), "should recover by skipping +");
        assertEquals(1, result.errorCount(), "one error: skip +");
        assertTrue(result.skipped().contains("+"));
    }

    @Test
    void testLRRecovery06_unclosedParen() {
        // Input '(n+n' has unclosed paren
        var parser = new Parser(precedenceLR, "(n+n");
        var matchResult = parser.parse("S");
        // With recovery, should insert missing ')'
        assertTrue(matchResult != null && !matchResult.isMismatch(),
            "should succeed with recovery");
    }

    @Test
    void testLRRecovery07_extraCloseParen() {
        // Input 'n+n)' has extra close paren
        var result = parse(precedenceLR, "n+n)");
        assertFalse(result.success(), "should fail (extra close paren)");
    }

    // Ref LR Masking Tests
    // F1-LR-05 case: T -> T*F | F. Input "n+n*Xn".
    // Error is at 'X'.
    // Optimal recovery: T matches "n", * matches "*", F fails on "X". F recovery skips "X" -> "n". Total 1 error.
    // Suboptimal (current): T fails. E matches "n+n". E recursion fails. E recovery skips "*X". Total 2 errors.

    private static final Map<String, Clause> maskingGrammar = Map.of(
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
    void testMASK01_errorAtTLevelAfterStar() {
        // Current behavior: 2 errors (recovery at E level).
        // Optimal behavior (future goal): 1 error (recovery at F level).
        // This is a known limitation: Ref can mask deeper recovery opportunities.
        // The test expects current behavior, not optimal.
        var result = parse(maskingGrammar, "n+n*Xn", "E");
        assertTrue(result.success(), "should recover");
        assertEquals(2, result.errorCount(),
            "current: 2 errors (suboptimal, but correct)");
        assertTrue(result.skipped().stream().anyMatch(s -> s.contains("*") || s.contains("X")),
            "should skip * and/or X");
    }
}
