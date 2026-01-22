// ===========================================================================
// BOUND PROPAGATION TESTS (FIX #9 Verification)
// ===========================================================================
// These tests verify that bounds propagate through arbitrary nesting levels
// to correctly stop repetitions before consuming delimiters.

package com.squirrelparser;

import static com.squirrelparser.TestUtils.testParse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class BoundPropagationTest {

    @Test
    void bp01_directRepetition() {
        // Baseline: Bound with direct Repetition child (was already working)
        var result = testParse("S <- \"x\"+ \"end\" ;", "xxxxend");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void bp02_throughRef() {
        // FIX #9: Bound propagates through Ref
        String grammar = """
            S <- A "end" ;
            A <- "x"+ ;
            """;
        var result = testParse(grammar, "xxxxend");
        assertTrue(result.ok(), "should succeed (bound through Ref)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void bp03_throughNestedRefs() {
        // FIX #9: Bound propagates through multiple Refs
        String grammar = """
            S <- A "end" ;
            A <- B ;
            B <- "x"+ ;
            """;
        var result = testParse(grammar, "xxxxend");
        assertTrue(result.ok(), "should succeed (bound through 2 Refs)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void bp04_throughFirst() {
        // FIX #9: Bound propagates through First alternatives
        String grammar = """
            S <- A "end" ;
            A <- "x"+ / "y"+ ;
            """;
        var result = testParse(grammar, "xxxxend");
        assertTrue(result.ok(), "should succeed (bound through First)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void bp05_leftRecursiveWithRepetition() {
        // FIX #9: The EMERG-01 case - bound through LR + First + Seq + Repetition
        String grammar = """
            S <- E "end" ;
            E <- E "+" "n"+ / "n" ;
            """;
        var result = testParse(grammar, "n+nnn+nnend");
        assertTrue(result.ok(), "should succeed (bound through LR)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void bp06_withRecoveryInsideBoundedRep() {
        // FIX #9 + recovery: Bound propagates AND recovery works inside repetition
        String grammar = """
            S <- A "end" ;
            A <- "ab"+ ;
            """;
        var result = testParse(grammar, "abXabYabend");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors (X and Y)");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        assertTrue(result.skippedStrings().contains("Y"), "should skip Y");
    }

    @Test
    void bp07_multipleBoundsNestedSeq() {
        // Multiple bounds in nested Seq structures
        String grammar = """
            S <- A ";" B "end" ;
            A <- "x"+ ;
            B <- "y"+ ;
            """;
        var result = testParse(grammar, "xxxx;yyyyend");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // A stops at ';', B stops at 'end'
    }

    @Test
    void bp08_boundVsEof() {
        // Without explicit bound, should consume until EOF
        var result = testParse("S <- \"x\"+ ;", "xxxx");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // No bound, so consumes all x's
    }

    @Test
    void bp09_zeroormoreWithBound() {
        // Bound applies to ZeroOrMore too
        var result = testParse("S <- \"x\"* \"end\" ;", "end");
        assertTrue(result.ok(), "should succeed (ZeroOrMore matches 0)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void bp10_complexNesting() {
        // Deeply nested: Ref -> First -> Seq -> Ref -> Repetition
        String grammar = """
            S <- A "end" ;
            A <- "a" B / "fallback" ;
            B <- "x"+ ;
            """;
        var result = testParse(grammar, "axxxxend");
        assertTrue(result.ok(), "should succeed (bound through complex nesting)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    // ===========================================================================
    // Additional tests for transparent rule skipping and repetition bounds
    // ===========================================================================

    @Test
    void bpr01_repetitionStopsAtSiblingTerminal() {
        // OneOrMore should stop when sibling terminal can match
        var result = testParse("S <- \"x\"+ \"Y\" ;", "xxY");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have no errors");
    }

    @Test
    void bpr02_repetitionStopsAtSiblingAfterError() {
        // After recovering from error, repetition should still respect sibling
        var result = testParse("S <- \"x\"+ \"Y\" ;", "xZxY");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (Z)");
        assertTrue(result.skippedStrings().contains("Z"), "should skip Z");
        assertTrue(!result.skippedStrings().contains("Y"), "should NOT skip Y");
    }

    @Test
    void bpr03_repetitionStopsAtOptionalSibling() {
        // Repetition should stop when optional sibling can match
        var result = testParse("S <- \"x\"+ \"!\"? ;", "xx!");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have no errors");
    }

    @Test
    void bpr04_repetitionWithErrorStopsAtOptionalSibling() {
        // After error recovery, repetition should stop at optional sibling
        var result = testParse("S <- \"x\"+ \"!\"? ;", "xZx!");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (Z)");
        assertTrue(!result.skippedStrings().contains("!"), "should NOT skip !");
    }

    @Test
    void wbs01_bracketBoundThroughWhitespace() {
        // The "]" should be the effective bound, not WS
        String grammar = """
            S <- "[" WS Items WS "]" ;
            Items <- Item* ;
            Item <- "x" ;
            ~WS <- [ ]* ;
            """;
        var result = testParse(grammar, "[xx]");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have no errors");
    }

    @Test
    void wbs03_bracketBoundWithErrorBeforeClose() {
        // Error recovery should stop at "]", not consume it
        String grammar = """
            S <- "[" WS Items WS "]" ;
            Items <- Item* ;
            Item <- "x" ;
            ~WS <- [ ]* ;
            """;
        var result = testParse(grammar, "[xZx]");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (Z)");
        assertTrue(!result.skippedStrings().contains("]"), "should NOT skip ]");
    }

    @Test
    void als01_simpleArrayValid() {
        String grammar = """
            S <- "[" (V ("," V)*)? "]" ;
            V <- [0-9]+ ;
            """;
        var result = testParse(grammar, "[1,2,3]");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have no errors");
    }

    @Test
    void als03_arrayWithErrorInMiddle() {
        // Error between values should be recovered, ] should still match
        String grammar = """
            S <- "[" WS (V (WS "," WS V)*)? WS "]" ;
            V <- [0-9]+ ;
            ~WS <- [ ]* ;
            """;
        var result = testParse(grammar, "[1,2X,3]");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (X)");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        assertTrue(!result.skippedStrings().contains("]"), "should NOT skip ]");
    }

    @Test
    void als06_nestedArrays() {
        // Nested arrays - inner ] should not be consumed by outer repetition
        String grammar = """
            S <- "[" WS (V (WS "," WS V)*)? WS "]" ;
            V <- S / [0-9]+ ;
            ~WS <- [ ]* ;
            """;
        var result = testParse(grammar, "[[1,2],3]");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have no errors");
    }

    @Test
    void rdr01_refToWhitespaceSkipped() {
        // Transparent WS should be skipped, non-transparent RBRACKET should be bound
        String grammar = """
            S <- "[" WS Items WS RBRACKET ;
            Items <- Item* ;
            Item <- "x" ;
            ~WS <- [ ]* ;
            RBRACKET <- "]" ;
            """;
        var result = testParse(grammar, "[xZx]");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (Z)");
        assertTrue(!result.skippedStrings().contains("]"), "should NOT skip ]");
    }

    @Test
    void rsb01_noTrailingSkipPastDelimiter() {
        // Trailing garbage recovery should stop at delimiter
        String grammar = """
            S <- "[" Items "]" ;
            Items <- "x"+ ;
            """;
        var result = testParse(grammar, "[xZ]");
        assertTrue(result.ok(), "should succeed");
        assertTrue(!result.skippedStrings().contains("]"), "should NOT skip ]");
    }

    @Test
    void ctr01_charsetRepetitionNoRecovery() {
        // CharSet repetition should NOT try to skip over non-matching content
        String grammar = """
            S <- [a-z]+ "!" ;
            """;
        var result = testParse(grammar, "abXcd!");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
    }

    @Test
    void ctr03_complexSubclauseDoesRecovery() {
        // Repetition of complex clauses (Seq) SHOULD do recovery
        String grammar = """
            S <- ("ab")+ "!" ;
            """;
        var result = testParse(grammar, "abXab!");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (X)");
        assertTrue(!result.skippedStrings().contains("!"), "should NOT skip !");
    }

    // ===========================================================================
    // Additional tests to match Dart test coverage
    // ===========================================================================

    @Test
    void bpr05_nestedRepetitionRespectsOuterBound() {
        String grammar = """
            S <- "[" Items "]" ;
            Items <- Item* ;
            Item <- "x" ;
            """;
        var result = testParse(grammar, "[xx]");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have no errors");
    }

    @Test
    void bpr06_nestedRepetitionWithErrorRespectsBound() {
        String grammar = """
            S <- "[" Items "]" ;
            Items <- Item* ;
            Item <- "x" ;
            """;
        var result = testParse(grammar, "[xZx]");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (Z)");
        assertTrue(!result.skippedStrings().contains("]"), "should NOT skip ]");
    }

    @Test
    void wbs02_bracketBoundWithActualWhitespace() {
        String grammar = """
            S <- "[" WS Items WS "]" ;
            Items <- (WS Item)* ;
            Item <- "x" ;
            ~WS <- [ ]* ;
            """;
        var result = testParse(grammar, "[ x x ]");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have no errors");
    }

    @Test
    void wbs04_braceBoundThroughWhitespace() {
        String grammar = """
            S <- "{" WS Items WS "}" ;
            Items <- Item* ;
            Item <- "x" ;
            ~WS <- [ ]* ;
            """;
        var result = testParse(grammar, "{xZx}");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (Z)");
        assertTrue(!result.skippedStrings().contains("}"), "should NOT skip }");
    }

    @Test
    void wbs05_multipleWhitespaceLayers() {
        String grammar = """
            S <- "[" WS1 WS2 Items WS1 WS2 "]" ;
            Items <- Item* ;
            Item <- "x" ;
            ~WS1 <- [ ]* ;
            ~WS2 <- [\t]* ;
            """;
        var result = testParse(grammar, "[xZx]");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (Z)");
        assertTrue(!result.skippedStrings().contains("]"), "should NOT skip ]");
    }

    @Test
    void als02_arrayWithWhitespaceValid() {
        String grammar = """
            S <- "[" WS (V (WS "," WS V)*)? WS "]" ;
            V <- [0-9]+ ;
            ~WS <- [ ]* ;
            """;
        var result = testParse(grammar, "[ 1 , 2 , 3 ]");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have no errors");
    }

    @Test
    void rdr02_multipleRefsWhitespaceAllSkipped() {
        String grammar = """
            S <- "[" SP TAB Items SP TAB RBRACKET ;
            Items <- Item* ;
            Item <- "x" ;
            ~SP <- [ ]* ;
            ~TAB <- [\t]* ;
            RBRACKET <- "]" ;
            """;
        var result = testParse(grammar, "[xZx]");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (Z)");
        assertTrue(!result.skippedStrings().contains("]"), "should NOT skip ]");
    }

    @Test
    void rsb02_recoveryScanStopsAtDelimiter() {
        String grammar = """
            S <- "[" Items "]" ;
            Items <- ("ab")+ ;
            """;
        var result = testParse(grammar, "[abZ]");
        assertTrue(result.ok(), "should succeed");
        assertTrue(!result.skippedStrings().contains("]"), "should NOT skip ]");
    }

    @Test
    void rsb03_multipleDelimitersNested() {
        String grammar = """
            S <- "[" Inner "]" ;
            Inner <- "{" Items "}" ;
            Items <- "x"+ ;
            """;
        var result = testParse(grammar, "[{xZ}]");
        assertTrue(result.ok(), "should succeed");
        assertTrue(!result.skippedStrings().contains("}"), "should NOT skip }");
        assertTrue(!result.skippedStrings().contains("]"), "should NOT skip ]");
    }
}
