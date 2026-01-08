package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.FollowedBy;
import com.squirrelparser.Combinators.NotFollowedBy;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Optional;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Combinators.ZeroOrMore;
import com.squirrelparser.Terminals.Str;

/**
 * COMPLEX INTERACTIONS TESTS
 * Port of complex_interactions_test.dart
 *
 * These tests verify complex combinations of features working together.
 */
class ComplexInteractionsTest {

    @Test
    void testCOMPLEX01_lrBoundRecoveryAllTogether() {
        // LR + bound propagation + recovery all working together (EMERG-01 verified)
        var r = parse(Map.of(
            "S", new Seq(new Ref("E"), new Str("end")),
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new OneOrMore(new Str("n"))),
                new Str("n")
            )
        ), "n+nXn+nnend");
        assertTrue(r.success(), "should succeed (FIX #9 bound propagation)");
        assertTrue(r.errorCount() > 0, "should have at least 1 error");
        assertTrue(r.skipped().contains("X"), "should skip X");
        // LR expands, OneOrMore with recovery, bound stops before 'end'
    }

    @Test
    void testCOMPLEX02_nestedFirstWithDifferentRecoveryCosts() {
        // Nested First, each with alternatives requiring different recovery
        var r = parse(Map.of(
            "S", new First(
                new Seq(
                    new First(new Str("x"), new Str("y")),
                    new Str("z")
                ),
                new Str("a")
            )
        ), "xXz");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should choose first alternative with recovery");
        // Outer First chooses first alternative (Seq)
        // Inner First chooses first alternative 'x'
        // Then skip X, match 'z'
    }

    @Test
    void testCOMPLEX03_recoveryVersionOverflowVerified() {
        // Many recoveries to test version counter doesn't overflow
        var sb = new StringBuilder("ab");
        for (int i = 0; i < 50; i++) {
            sb.append("Xab");
        }
        var r = parse(Map.of("S", new OneOrMore(new Str("ab"))), sb.toString());
        assertTrue(r.success(), "should succeed (version counter handles 50+ recoveries)");
        assertEquals(50, r.errorCount(), "should count all 50 errors");
    }

    @Test
    void testCOMPLEX04_probeDuringRecovery() {
        // ZeroOrMore uses probe while recovery is happening
        var r = parse(Map.of(
            "S", new Seq(
                new ZeroOrMore(new Str("x")),
                new First(new Str("y"), new Str("z"))
            )
        ), "xXxz");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skipped().contains("X"), "should skip X");
        // ZeroOrMore with recovery inside, probes to find 'z'
    }

    @Test
    void testCOMPLEX05_multipleRefsSameRuleWithRecovery() {
        // Multiple Refs to same rule, each with independent recovery
        var r = parse(Map.of(
            "S", new Seq(new Ref("A"), new Str("+"), new Ref("A")),
            "A", new Str("n")
        ), "nX+n");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
        // First Ref('A') needs recovery, second Ref('A') is clean
    }

    @Test
    void testCOMPLEX06_deeplyNestedLR() {
        // Multiple LR levels with recovery at different depths
        var r = parse(Map.of(
            "A", new First(
                new Seq(new Ref("A"), new Str("a"), new Ref("B")),
                new Ref("B")
            ),
            "B", new First(
                new Seq(new Ref("B"), new Str("b"), new Str("x")),
                new Str("x")
            )
        ), "xbXxaXxbx", "A");
        assertTrue(r.success(), "should succeed");
        assertEquals(2, r.errorCount(), "should have 2 errors (X's at both A and B levels)");
    }

    @Test
    void testCOMPLEX07_recoveryWithLookahead() {
        // Recovery near lookahead assertions
        var r = parse(Map.of(
            "S", new Seq(new Str("a"), new FollowedBy(new Str("b")), new Str("b"), new Str("c"))
        ), "aXbc");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skipped().contains("X"), "should skip X");
        // After skipping X, FollowedBy(b) checks 'b' without consuming
    }

    @Test
    void testCOMPLEX08_recoveryInNegativeLookahead() {
        // NotFollowedBy with recovery context
        var r = parse(Map.of(
            "S", new Seq(new Str("a"), new NotFollowedBy(new Str("x")), new Str("b"))
        ), "ab");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
        // NotFollowedBy('x') succeeds (next is 'b', not 'x')
    }

    @Test
    void testCOMPLEX09_alternatingLRAndRepetition() {
        // Grammar with both LR and repetitions at same level
        var r = parse(Map.of(
            "S", new Seq(new Ref("E"), new Str(";"), new OneOrMore(new Str("x"))),
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            )
        ), "n+n;xxx");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
        // E is left-recursive, then ';', then repetition
    }

    @Test
    void testCOMPLEX10_recoverySpanningMultipleClauses() {
        // Single error region that spans where multiple clauses would try to match
        var r = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("b"), new Str("c"), new Str("d"))
        ), "aXYZbcd");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error (entire XYZ region)");
        assertTrue(r.skipped().contains("XYZ"), "should skip XYZ as single region");
    }

    @Test
    void testCOMPLEX11_refThroughMultipleIndirections() {
        // A -> B -> C -> D, all Refs
        var r = parse(Map.of(
            "A", new Ref("B"),
            "B", new Ref("C"),
            "C", new Ref("D"),
            "D", new Str("x")
        ), "x", "A");
        assertTrue(r.success(), "should succeed (multiple Ref indirections)");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testCOMPLEX12_circularRefsWithRecovery() {
        // Mutual recursion with simple clean input
        var r = parse(Map.of(
            "S", new Seq(new Ref("A"), new Str("end")),
            "A", new First(
                new Seq(new Str("a"), new Ref("B")),
                new Str("a")
            ),
            "B", new First(
                new Seq(new Str("b"), new Ref("A")),
                new Str("b")
            )
        ), "ababend", "S");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors (clean parse)");
        // Mutual recursion: A -> B -> A -> B (abab)
    }

    @Test
    void testCOMPLEX13_allClauseTypesInOneGrammar() {
        // Every clause type in one complex grammar
        var r = parse(Map.of(
            "S", new Seq(
                new Ref("A"),
                new Optional(new Str("opt")),
                new ZeroOrMore(new Str("z")),
                new First(new Str("f1"), new Str("f2")),
                new FollowedBy(new Str("end")),
                new Str("end")
            ),
            "A", new First(
                new Seq(new Ref("A"), new Str("+"), new Str("a")),
                new Str("a")
            )
        ), "a+aoptzzzf1end", "S");
        assertTrue(r.success(), "should succeed (all clause types work together)");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testCOMPLEX14_recoveryAtEveryLevelOfDeepNesting() {
        // Error at each level of deep nesting, all recover
        var r = parse(Map.of(
            "S", new Seq(
                new Seq(
                    new Str("a"),
                    new Seq(
                        new Str("b"),
                        new Seq(new Str("c"), new Str("d"))
                    )
                )
            )
        ), "aXbYcZd");
        assertTrue(r.success(), "should succeed");
        assertEquals(3, r.errorCount(), "should have 3 errors");
        // Error at each nesting level
    }

    @Test
    void testCOMPLEX15_performanceLargeGrammar() {
        // Large grammar with many rules
        var rules = new HashMap<String, Clause>();
        for (int i = 0; i < 50; i++) {
            rules.put("Rule" + i, new Str("opt_" + String.format("%03d", i)));
        }
        var refs = new ArrayList<Clause>();
        for (int i = 0; i < 50; i++) {
            refs.add(new Ref("Rule" + i));
        }
        rules.put("S", new First(refs.toArray(new Clause[0])));

        var r = parse(rules, "opt_025", "S");
        assertTrue(r.success(), "should succeed (large grammar with 50 rules)");
    }
}
