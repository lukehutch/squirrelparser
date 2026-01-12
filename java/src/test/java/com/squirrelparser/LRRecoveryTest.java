// ===========================================================================
// SECTION 13: LEFT RECURSION ERROR RECOVERY
// ===========================================================================

package com.squirrelparser;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Nested;

import static org.junit.jupiter.api.Assertions.*;

class LRRecoveryTest {
    // directLR grammar for error recovery tests
    private static final String DIRECT_LR = """
        S <- E ;
        E <- E "+n" / "n" ;
        """;

    // precedenceLR grammar for error recovery tests
    private static final String PRECEDENCE_LR = """
        S <- E ;
        E <- E "+" T / E "-" T / T ;
        T <- T "*" F / T "/" F / F ;
        F <- "(" E ")" / "n" ;
        """;

    // Error recovery in direct LR grammar
    @Test
    void testLRRecovery01LeadingError() {
        // Input '+n+n+n+' starts with '+' which is invalid (need 'n' first)
        // and ends with '+' which is also invalid (need 'n' after)
        var r = TestUtils.testParse(DIRECT_LR, "+n+n+n+");
        // This should fail because we can't recover a valid parse
        // The leading '+' prevents any initial 'n' match
        assertFalse(r.ok(), "should fail (leading + is unrecoverable)");
    }

    @Test
    void testLRRecovery02InternalError() {
        // Input 'n+Xn+n' has garbage 'X' between + and n
        // '+n' is a 2-char terminal, so 'n+X' doesn't match '+n'
        // Grammar can only match 'n' at start, rest is captured as error
        var r = TestUtils.testParse(DIRECT_LR, "n+Xn+n");
        assertTrue(r.ok(), "should capture trailing as error");
        assertEquals(1, r.errorCount(), "should have 1 error (unmatched +Xn+n)");
    }

    @Test
    void testLRRecovery03TrailingJunk() {
        // Input 'n+n+nXXX' has trailing garbage
        // With new invariant, trailing is captured as error in parse tree
        var r = TestUtils.testParse(DIRECT_LR, "n+n+nXXX");
        assertTrue(r.ok(), "should succeed with trailing captured");
        assertEquals(1, r.errorCount(), "should have 1 error (trailing XXX)");
        assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("XXX")), "should capture XXX");
    }

    // Error recovery in precedence grammar
    @Test
    void testLRRecovery04MissingOperand() {
        // Input 'n+*n' has missing operand between + and *
        // Parser recovers by skipping the extra '+' to parse as 'n*n'
        var r = TestUtils.testParse(PRECEDENCE_LR, "n+*n");
        assertTrue(r.ok(), "should recover by skipping +");
        assertEquals(1, r.errorCount(), "one error: skip +");
        assertEquals(java.util.List.of("+"), r.skippedStrings());
    }

    @Test
    void testLRRecovery05DoubleOp() {
        // Input 'n++n' has double operator
        // Parser recovers by skipping the extra '+' to parse as 'n+n'
        var r = TestUtils.testParse(PRECEDENCE_LR, "n++n");
        assertTrue(r.ok(), "should recover by skipping +");
        assertEquals(1, r.errorCount(), "one error: skip +");
        assertEquals(java.util.List.of("+"), r.skippedStrings());
    }

    @Test
    void testLRRecovery06UnclosedParen() {
        // Input '(n+n' has unclosed paren
        var parseResult = SquirrelParser.squirrelParsePT(PRECEDENCE_LR, "S", "(n+n");
        var result = parseResult.root();
        // With recovery, should insert missing ')'
        assertFalse(result.isMismatch(), "should succeed with recovery");
    }

    @Test
    void testLRRecovery07ExtraCloseParen() {
        // Input 'n+n)' has extra close paren
        // With new invariant, trailing is captured as error
        var r = TestUtils.testParse(PRECEDENCE_LR, "n+n)");
        assertTrue(r.ok(), "should succeed with trailing captured");
        assertEquals(1, r.errorCount(), "should have 1 error (trailing ))");
        assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains(")")), "should capture )");
    }

    @Nested
    class RefLRMaskingTests {
        // F1-LR-05 case: T -> T*F | F. Input "n+n*Xn".
        // Error is at 'X'.
        // Optimal recovery: T matches "n", * matches "*", F fails on "X". F recovery skips "X" -> "n". Total 1 error.
        // Suboptimal (current): T fails. E matches "n+n". E recursion fails. E recovery skips "*X". Total 2 errors.

        private static final String GRAMMAR = """
            E <- E "+" T / T ;
            T <- T "*" F / F ;
            F <- "(" E ")" / "n" ;
            """;

        @Test
        void testMask01ErrorAtTLevelAfterStar() {
            // Current behavior: 2 errors (recovery at E level).
            // Optimal behavior (future goal): 1 error (recovery at F level).
            // This is a known limitation: Ref can mask deeper recovery opportunities.
            // The test expects current behavior, not optimal.
            var r = TestUtils.testParse(GRAMMAR, "n+n*Xn", "E");
            assertTrue(r.ok(), "should recover");
            assertEquals(2, r.errorCount(), "current: 2 errors (suboptimal, but correct)");
            assertTrue(r.skippedStrings().stream().anyMatch(s -> s.contains("*") || s.contains("X")),
                "should skip * and/or X");
        }
    }
}
