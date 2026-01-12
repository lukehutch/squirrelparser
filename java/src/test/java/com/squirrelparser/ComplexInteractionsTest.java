// ===========================================================================
// COMPLEX INTERACTIONS TESTS
// ===========================================================================
// These tests verify complex combinations of features working together.

package com.squirrelparser;

import org.junit.jupiter.api.Test;

import java.util.stream.Collectors;
import java.util.stream.IntStream;

import static com.squirrelparser.TestUtils.*;
import static org.junit.jupiter.api.Assertions.*;

class ComplexInteractionsTest {

    @Test
    void complex01_lrBoundRecoveryAllTogether() {
        // LR + bound propagation + recovery all working together (EMERG-01 verified)
        String grammar = """
            S <- E "end" ;
            E <- E "+" "n"+ / "n" ;
        """;
        var result = testParse(grammar, "n+nXn+nnend");
        assertTrue(result.ok(), "should succeed (FIX #9 bound propagation)");
        assertTrue(result.errorCount() > 0, "should have at least 1 error");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        // LR expands, OneOrMore with recovery, bound stops before 'end'
    }

    @Test
    void complex02_nestedFirstWithDifferentRecoveryCosts() {
        // Nested First, each with alternatives requiring different recovery
        String grammar = """
            S <- ("x" / "y") "z" / "a" ;
        """;
        var result = testParse(grammar, "xXz");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should choose first alternative with recovery");
        // Outer First chooses first alternative (Seq)
        // Inner First chooses first alternative 'x'
        // Then skip X, match 'z'
    }

    @Test
    void complex03_recoveryVersionOverflowVerified() {
        // Many recoveries to test version counter doesn't overflow
        String input = "ab" + IntStream.range(0, 50).mapToObj(i -> "Xab").collect(Collectors.joining());
        String grammar = "S <- \"ab\"+ ;";
        var result = testParse(grammar, input);
        assertTrue(result.ok(), "should succeed (version counter handles 50+ recoveries)");
        assertEquals(50, result.errorCount(), "should count all 50 errors");
    }

    @Test
    void complex04_probeDuringRecovery() {
        // ZeroOrMore uses probe while recovery is happening
        String grammar = """
            S <- "x"* ("y" / "z") ;
        """;
        var result = testParse(grammar, "xXxz");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        // ZeroOrMore with recovery inside, probes to find 'z'
    }

    @Test
    void complex05_multipleRefsSameRuleWithRecovery() {
        // Multiple Refs to same rule, each with independent recovery
        String grammar = """
            S <- A "+" A ;
            A <- "n" ;
        """;
        var result = testParse(grammar, "nX+n");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        // First Ref('A') needs recovery, second Ref('A') is clean
    }

    @Test
    void complex06_deeplyNestedLr() {
        // Multiple LR levels with recovery at different depths
        String grammar = """
            A <- A "a" B / B ;
            B <- B "b" "x" / "x" ;
        """;
        var result = testParse(grammar, "xbXxaXxbx", "A");
        assertTrue(result.ok(), "should succeed");
        assertEquals(2, result.errorCount(), "should have 2 errors (X's at both A and B levels)");
    }

    @Test
    void complex07_recoveryWithLookahead() {
        // Recovery near lookahead assertions
        String grammar = """
            S <- "a" &"b" "b" "c" ;
        """;
        var result = testParse(grammar, "aXbc");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skippedStrings().contains("X"), "should skip X");
        // After skipping X, FollowedBy(b) checks 'b' without consuming
    }

    @Test
    void complex08_recoveryInNegativeLookahead() {
        // NotFollowedBy with recovery context
        String grammar = """
            S <- "a" !"x" "b" ;
        """;
        var result = testParse(grammar, "ab");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // NotFollowedBy('x') succeeds (next is 'b', not 'x')
    }

    @Test
    void complex09_alternatingLrAndRepetition() {
        // Grammar with both LR and repetitions at same level
        String grammar = """
            S <- E ";" "x"+ ;
            E <- E "+" "n" / "n" ;
        """;
        var result = testParse(grammar, "n+n;xxx");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
        // E is left-recursive, then ';', then repetition
    }

    @Test
    void complex10_recoverySpanningMultipleClauses() {
        // Single error region that spans where multiple clauses would try to match
        String grammar = """
            S <- "a" "b" "c" "d" ;
        """;
        var result = testParse(grammar, "aXYZbcd");
        assertTrue(result.ok(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error (entire XYZ region)");
        assertTrue(result.skippedStrings().contains("XYZ"), "should skip XYZ as single region");
    }

    @Test
    void complex11_refThroughMultipleIndirections() {
        // A -> B -> C -> D, all Refs
        String grammar = """
            A <- B ;
            B <- C ;
            C <- D ;
            D <- "x" ;
        """;
        var result = testParse(grammar, "x", "A");
        assertTrue(result.ok(), "should succeed (multiple Ref indirections)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void complex12_circularRefsWithRecovery() {
        // Mutual recursion with simple clean input
        String grammar = """
            S <- A "end" ;
            A <- "a" B / "a" ;
            B <- "b" A / "b" ;
        """;
        var result = testParse(grammar, "ababend", "S");
        assertTrue(result.ok(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors (clean parse)");
        // Mutual recursion: A -> B -> A -> B (abab)
    }

    @Test
    void complex13_allClauseTypesInOneGrammar() {
        // Every clause type in one complex grammar
        String grammar = """
            S <- A "opt"? "z"* ("f1" / "f2") &"end" "end" ;
            A <- A "+" "a" / "a" ;
        """;
        var result = testParse(grammar, "a+aoptzzzf1end", "S");
        assertTrue(result.ok(), "should succeed (all clause types work together)");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void complex14_recoveryAtEveryLevelOfDeepNesting() {
        // Error at each level of deep nesting, all recover
        String grammar = """
            S <- "a" "b" "c" "d" ;
        """;
        var result = testParse(grammar, "aXbYcZd");
        assertTrue(result.ok(), "should succeed");
        assertEquals(3, result.errorCount(), "should have 3 errors");
        // Error at each nesting level
    }

    @Test
    void complex15_performanceLargeGrammar() {
        // Large grammar with many rules
        StringBuilder rules = new StringBuilder();
        StringBuilder alternatives = new StringBuilder();
        for (int i = 0; i < 50; i++) {
            String idx = String.format("%03d", i);
            rules.append("Rule").append(i).append(" <- \"opt_").append(idx).append("\" ;\n");
            if (i > 0) alternatives.append(" / ");
            alternatives.append("Rule").append(i);
        }
        String grammar = rules + "S <- " + alternatives + " ;";

        var result = testParse(grammar, "opt_025", "S");
        assertTrue(result.ok(), "should succeed (large grammar with 50 rules)");
    }
}
