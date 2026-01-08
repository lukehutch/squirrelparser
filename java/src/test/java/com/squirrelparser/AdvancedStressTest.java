package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashMap;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.NotFollowedBy;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Optional;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Combinators.ZeroOrMore;
import com.squirrelparser.Terminals.CharRange;
import com.squirrelparser.Terminals.Str;

/**
 * ADVANCED STRESS TESTS FOR SQUIRREL PARSER RECOVERY (41 tests)
 * Port of advanced_stress_test.dart
 *
 * These tests attempt to expose edge cases, subtle bugs, and potential
 * violations of the three invariants (Completeness, Isolation, Minimality).
 */
class AdvancedStressTest {

    // Helper to create grammar maps with explicit typing
    @SafeVarargs
    private static Map<String, Clause> grammar(Map.Entry<String, Clause>... entries) {
        var map = new HashMap<String, Clause>();
        for (var entry : entries) {
            map.put(entry.getKey(), entry.getValue());
        }
        return map;
    }

    private static Map.Entry<String, Clause> rule(String name, Clause clause) {
        return Map.entry(name, clause);
    }

    // ===========================================================================
    // SECTION A: PHASE ISOLATION ATTACKS
    // ===========================================================================

    @Test
    void testISO01ProbeDuringRecoveryProbe() {
        var g = grammar(
            rule("S", new Seq(new ZeroOrMore(new Ref("A")), new Ref("B"))),
            rule("A", new Seq(new OneOrMore(new Str("a")), new Str("x"))),
            rule("B", new Seq(new Str("b"), new Str("z")))
        );
        var r = parse(g, "aaXxbz");
        assertTrue(r.success(), "nested probe should not poison cache");
    }

    @Test
    void testISO02RecoveryVersionOverflow() {
        var g = grammar(rule("S", new OneOrMore(new Str("ab"))));
        var input = "ab" + IntStream.range(0, 50).mapToObj(i -> "Xab").collect(Collectors.joining());
        var r = parse(g, input);
        assertTrue(r.success(), "many errors should not overflow version");
        assertEquals(50, r.errorCount(), "should count all 50 errors");
    }

    @Test
    void testISO03AlternatingProbeMatch() {
        var g = grammar(
            rule("S", new Seq(
                new ZeroOrMore(new Ref("A")),
                new ZeroOrMore(new Ref("B")),
                new Str("end")
            )),
            rule("A", new Str("a")),
            rule("B", new Str("a"))
        );
        var r = parse(g, "aaaXend");
        assertTrue(r.success(), "ambiguous probes should resolve correctly");
    }

    @Test
    void testISO04CompleteResultReuseAfterLR() {
        var g = grammar(
            rule("S", new Seq(new Ref("A"), new Ref("E"))),
            rule("A", new Str("a")),
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("a")),
                new Str("a")
            ))
        );
        var r = parse(g, "aa+a");
        assertTrue(r.success(), "complete result should be isolated from LR");
        assertEquals(0, r.errorCount(), "clean parse");
    }

    @Test
    void testISO05MismatchCacheAcrossPhases() {
        var g = grammar(
            rule("S", new First(
                new Seq(new Str("abc"), new Str("xyz")),
                new Seq(new Str("ab"), new Str("z"))
            ))
        );
        var r = parse(g, "abXz");
        assertTrue(r.success(), "Phase 1 mismatch should not block Phase 2");
    }

    // ===========================================================================
    // SECTION B: LEFT RECURSION EDGE CASES
    // ===========================================================================

    @Test
    void testLREdge01TripleNestedLR() {
        var g = grammar(
            rule("A", new First(
                new Seq(new Ref("A"), new Str("+"), new Ref("B")),
                new Ref("B")
            )),
            rule("B", new First(
                new Seq(new Ref("B"), new Str("*"), new Ref("C")),
                new Ref("C")
            )),
            rule("C", new First(
                new Seq(new Ref("C"), new Str("-"), new Str("n")),
                new Str("n")
            ))
        );
        var r = parse(g, "n+n*n-Xn", "A");
        assertTrue(r.success(), "triple LR should recover");
    }

    @Test
    void testLREdge02LRInsideRepetition() {
        var g = grammar(
            rule("S", new OneOrMore(new Ref("E"))),
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            ))
        );
        var r = parse(g, "n+nXn+n");
        assertTrue(r.success(), "LR inside repetition should work");
    }

    @Test
    void testLREdge03LRWithLookahead() {
        var g = grammar(
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+"), new Ref("T")),
                new Ref("T")
            )),
            rule("T", new Seq(new NotFollowedBy(new Str("+")), new Str("n")))
        );
        var r = parse(g, "n+Xn", "E");
        assertTrue(r.success(), "LR with lookahead should recover");
    }

    @Test
    void testLREdge04MutualLR() {
        var g = grammar(
            rule("A", new First(
                new Seq(new Ref("B"), new Str("a")),
                new Str("x")
            )),
            rule("B", new First(
                new Seq(new Ref("A"), new Str("b")),
                new Str("y")
            ))
        );
        var r = parse(g, "ybaXba", "A");
        assertTrue(r.success(), "mutual LR should recover");
    }

    @Test
    void testLREdge05LRZeroLengthBetween() {
        var g = grammar(
            rule("E", new First(
                new Seq(new Ref("E"), new Optional(new Str(" ")), new Str("+"), new Str("n")),
                new Str("n")
            ))
        );
        var r = parse(g, "n +Xn", "E");
        assertTrue(r.success(), "LR with optional should recover");
    }

    @Test
    void testLREdge06LREmptyBase() {
        var g = grammar(
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Optional(new Str("n"))
            ))
        );
        @SuppressWarnings("unused")
        var r = parse(g, "+n+n", "E");
        assertTrue(true, "should not infinite loop");
    }

    // ===========================================================================
    // SECTION C: RECOVERY MINIMALITY ATTACKS
    // ===========================================================================

    @Test
    void testMIN01MultipleValidRecoveries() {
        var g = grammar(
            rule("S", new First(
                new Seq(new Str("a"), new Str("b"), new Str("c")),
                new Seq(new Str("a"), new Str("c"))
            ))
        );
        var r = parse(g, "aXc");
        assertTrue(r.success(), "should find recovery");
        assertEquals(1, r.errorCount(), "should choose minimal recovery");
    }

    @Test
    void testMIN02GrammarDeletionVsInputSkip() {
        var g = grammar(
            rule("S", new Seq(new Str("a"), new Str("b"), new Str("c"), new Str("d")))
        );
        var r = parse(g, "aXd");
        assertFalse(r.success(), "should fail (requires mid-parse grammar deletion)");

        var r2 = parse(g, "abc");
        assertTrue(r2.success(), "should succeed with EOF grammar deletion");
        assertEquals(1, r2.errorCount(), "delete d at EOF");
    }

    @Test
    void testMIN03GreedyRepetitionInteraction() {
        var g = grammar(
            rule("S", new Seq(new OneOrMore(new Str("a")), new Str("b")))
        );
        var r = parse(g, "aaaaXb");
        assertTrue(r.success(), "repetition should respect bounds");
        assertEquals(1, r.errorCount(), "should skip only X");
    }

    @Test
    void testMIN04NestedSeqRecovery() {
        var g = grammar(
            rule("S", new Seq(
                new Str("("),
                new Seq(new Str("a"), new Str("b")),
                new Str(")")
            ))
        );
        var r = parse(g, "(aXb)");
        assertTrue(r.success(), "inner Seq should recover by skipping X");
        assertEquals(1, r.errorCount(), "should skip only X");

        var r2 = parse(g, "(aX)");
        assertFalse(r2.success(), "should fail (requires mid-parse grammar deletion)");
    }

    @Test
    void testMIN05RecoveryPositionOptimization() {
        var g = grammar(
            rule("S", new Seq(new Str("aaa"), new Str("bbb")))
        );
        var r = parse(g, "aaXbbb");
        assertFalse(r.success(), "should fail (requires mid-parse grammar deletion)");
    }

    // ===========================================================================
    // SECTION D: COMPLETENESS ACCURACY ATTACKS
    // ===========================================================================

    @Test
    void testCOMP01NestedIncomplete() {
        var g = grammar(
            rule("S", new Seq(new Ref("A"), new Str("z"))),
            rule("A", new Seq(new Ref("B"), new Str("y"))),
            rule("B", new Seq(new Ref("C"), new Str("x"))),
            rule("C", new ZeroOrMore(new Str("a")))
        );
        var r = parse(g, "aaaQxyz");
        assertTrue(r.success(), "deeply nested incomplete should trigger recovery");
        assertEquals(1, r.errorCount(), "should skip Q");
    }

    @Test
    void testCOMP02OptionalInsideRepetition() {
        var g = grammar(
            rule("S", new Seq(
                new OneOrMore(new Seq(new Str("a"), new Optional(new Str("b")))),
                new Str("z")
            ))
        );
        var r = parse(g, "aabXaz");
        assertTrue(r.success(), "should recover");
    }

    @Test
    void testCOMP03FirstAlternativeIncomplete() {
        var g = grammar(
            rule("S", new First(
                new Seq(new ZeroOrMore(new Str("a")), new Str("x")),
                new Seq(new ZeroOrMore(new Str("a")), new Str("y"))
            ))
        );
        var r = parse(g, "aaaQy");
        assertTrue(r.success(), "should recover");
    }

    @Test
    void testCOMP04CompleteZeroLength() {
        var g = grammar(
            rule("S", new Seq(new ZeroOrMore(new Str("x")), new Str("a")))
        );
        var r = parse(g, "a");
        assertTrue(r.success(), "zero-length complete should work");
        assertEquals(0, r.errorCount(), "clean parse");
    }

    @Test
    void testCOMP05IncompleteAtEOF() {
        var g = grammar(
            rule("S", new Seq(new OneOrMore(new Str("a")), new Str("z")))
        );
        var r = parse(g, "aaa");
        assertTrue(r.success(), "should delete missing z");
    }

    // ===========================================================================
    // SECTION E: CACHE COHERENCE STRESS TESTS
    // ===========================================================================

    @Test
    void testCACHE01SameClauseMultiplePositions() {
        var g = grammar(
            rule("S", new Seq(new Ref("X"), new Str("+"), new Ref("X"))),
            rule("X", new Str("n"))
        );
        var r = parse(g, "nQn");
        assertFalse(r.success(), "requires mid-parse grammar deletion");

        var r2 = parse(g, "n+Xn");
        assertTrue(r2.success(), "same clause at different positions");
        assertEquals(1, r2.errorCount(), "skip X between + and n");
    }

    @Test
    void testCACHE02DiamondDependency() {
        var g = grammar(
            rule("S", new Seq(new Ref("A"), new Ref("B"))),
            rule("A", new Seq(new Str("a"), new Ref("C"))),
            rule("B", new Seq(new Str("b"), new Ref("C"))),
            rule("C", new Str("c"))
        );
        var r = parse(g, "acXbc");
        assertTrue(r.success(), "diamond dependency should work");
    }

    @Test
    void testCACHE03RepeatedLRAtSamePos() {
        var g = grammar(
            rule("S", new Seq(new Ref("E"), new Str(";"), new Ref("E"))),
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            ))
        );
        var r = parse(g, "n+n;n+Xn");
        assertTrue(r.success(), "repeated LR should work");
    }

    @Test
    void testCACHE04InterleavedLRAndNonLR() {
        var g = grammar(
            rule("S", new Seq(new Ref("E"), new Str(","), new Ref("F"), new Str(","), new Ref("E"))),
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            )),
            rule("F", new Str("xyz"))
        );
        var r = parse(g, "n+n,xyz,n+Xn");
        assertTrue(r.success(), "interleaved LR/non-LR should work");
    }

    @Test
    void testCACHE05RapidPhaseSwitching() {
        var g = grammar(
            rule("S", new Seq(
                new ZeroOrMore(new Ref("A")),
                new ZeroOrMore(new Ref("B")),
                new ZeroOrMore(new Ref("C")),
                new Str("end")
            )),
            rule("A", new Str("a")),
            rule("B", new Str("b")),
            rule("C", new Str("c"))
        );
        var r = parse(g, "aaaXbbbYcccZend");
        assertTrue(r.success(), "rapid phase switching should work");
    }

    // ===========================================================================
    // SECTION F: PATHOLOGICAL GRAMMARS
    // ===========================================================================

    private Clause buildDeepFirst(int depth, String terminal) {
        if (depth == 0) {
            return new Str(terminal);
        }
        return new First(new Str("x"), buildDeepFirst(depth - 1, terminal));
    }

    @Test
    void testPATH01DeeplyNestedFirst() {
        var g = grammar(rule("S", buildDeepFirst(20, "target")));
        var r = parse(g, "target");
        assertTrue(r.success(), "deep First should work");
    }

    private Clause buildDeepSeq(int depth) {
        if (depth == 0) {
            return new Str("x");
        }
        return new Seq(new Str("a"), buildDeepSeq(depth - 1));
    }

    @Test
    void testPATH02DeeplyNestedSeq() {
        var g = grammar(rule("S", new Seq(buildDeepSeq(20), new Str("end"))));
        var input = "a".repeat(20) + "Qx" + "end";
        var r = parse(g, input);
        assertTrue(r.success(), "deep Seq should recover");
    }

    @Test
    void testPATH03ManyAlternatives() {
        var alts = new Clause[51];
        for (int i = 0; i < 50; i++) {
            alts[i] = new Str("opt" + i);
        }
        alts[50] = new Str("target");
        var g = grammar(rule("S", new First(alts)));
        var r = parse(g, "target");
        assertTrue(r.success(), "many alternatives should work");
    }

    @Test
    void testPATH04WideSeq() {
        var elems = new Clause[30];
        for (int i = 0; i < 30; i++) {
            elems[i] = new Str(String.valueOf((char) (97 + (i % 26))));
        }
        var g = grammar(rule("S", new Seq(elems)));
        var sb = new StringBuilder();
        for (int i = 0; i < 30; i++) {
            sb.append((char) (97 + (i % 26)));
        }
        var input = sb.toString();
        var errInput = input.substring(0, 15) + "X" + input.substring(15);
        var r = parse(g, errInput);
        assertTrue(r.success(), "wide Seq should recover");
    }

    @Test
    void testPATH05RepetitionOfRepetition() {
        var g = grammar(rule("S", new OneOrMore(new OneOrMore(new Str("a")))));
        var r = parse(g, "aaaXaaa");
        assertTrue(r.success(), "nested repetition should work");
    }

    // ===========================================================================
    // SECTION G: REAL-WORLD GRAMMAR PATTERNS
    // ===========================================================================

    @Test
    void testREAL01JsonLikeArray() {
        var g = grammar(
            rule("Array", new Seq(new Str("["), new Optional(new Ref("Elements")), new Str("]"))),
            rule("Elements", new Seq(
                new Ref("Value"),
                new ZeroOrMore(new Seq(new Str(","), new Ref("Value")))
            )),
            rule("Value", new First(new Ref("Array"), new Str("n")))
        );
        var r = parse(g, "[n n]", "Array");
        assertTrue(r.success(), "should recover missing comma");
    }

    @Test
    void testREAL02ExpressionWithParens() {
        var g = grammar(
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+"), new Ref("T")),
                new Ref("T")
            )),
            rule("T", new First(
                new Seq(new Ref("T"), new Str("*"), new Ref("F")),
                new Ref("F")
            )),
            rule("F", new First(
                new Seq(new Str("("), new Ref("E"), new Str(")")),
                new Str("n")
            ))
        );
        var r = parse(g, "(n+n", "E");
        assertTrue(r.success(), "should insert missing close paren");
    }

    @Test
    void testREAL03StatementList() {
        var g = grammar(
            rule("Program", new OneOrMore(new Ref("Stmt"))),
            rule("Stmt", new Seq(new Ref("Expr"), new Str(";"))),
            rule("Expr", new First(
                new Seq(new Str("if"), new Str("("), new Ref("Expr"), new Str(")"), new Ref("Stmt")),
                new Str("x")
            ))
        );
        var r = parse(g, "x x;", "Program");
        assertTrue(r.success(), "should recover missing semicolon");
    }

    @Test
    void testREAL04StringLiteral() {
        var g = grammar(
            rule("S", new Seq(new Str("\""), new ZeroOrMore(new CharRange("a", "z")), new Str("\"")))
        );
        var r = parse(g, "\"hello");
        assertTrue(r.success(), "should insert missing quote");
    }

    @Test
    void testREAL05NestedBlocks() {
        var g = grammar(
            rule("Block", new Seq(new Str("{"), new ZeroOrMore(new Ref("Stmt")), new Str("}"))),
            rule("Stmt", new First(
                new Ref("Block"),
                new Seq(new Str("x"), new Str(";"))
            ))
        );
        var r = parse(g, "{x;{x;Xx;}}", "Block");
        assertTrue(r.success(), "nested blocks should recover");
    }

    // ===========================================================================
    // SECTION H: EMERGENT INTERACTION TESTS
    // ===========================================================================

    @Test
    void testEMERG01LRWithBoundedRepRecovery() {
        var g = grammar(
            rule("S", new Seq(new Ref("E"), new Str("end"))),
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+"), new OneOrMore(new Str("n"))),
                new Str("n")
            ))
        );
        var r = parse(g, "n+nXn+nnend");
        assertTrue(r.success(), "LR with bounded rep should work");
    }

    @Test
    void testEMERG02ProbeTriggersLR() {
        var g = grammar(
            rule("S", new Seq(new ZeroOrMore(new Str("a")), new Ref("E"))),
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            ))
        );
        var r = parse(g, "aaXn+n");
        assertTrue(r.success(), "probe triggering LR should work");
    }

    @Test
    void testEMERG03RecoveryResetsLRExpansion() {
        var g = grammar(
            rule("S", new Seq(new Ref("E"), new Str(";"), new Ref("E"))),
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            ))
        );
        var r = parse(g, "n+Xn;n+n+n");
        assertTrue(r.success(), "second LR should expand independently");
        assertEquals(1, r.errorCount(), "only first E has error");
    }

    @Test
    void testEMERG04IncompletePropagationThroughLR() {
        var g = grammar(
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+"), new Ref("T")),
                new Ref("T")
            )),
            rule("T", new Seq(new Str("n"), new ZeroOrMore(new Str("x"))))
        );
        var r = parse(g, "nxx+nxQx", "E");
        assertTrue(r.success(), "incomplete should propagate through LR");
    }

    @Test
    void testEMERG05CacheVersionAfterLRRecovery() {
        var g = grammar(
            rule("S", new Seq(new Ref("E"), new Str(";"), new Ref("E"))),
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            ))
        );
        var r = parse(g, "n+Xn+n;n+n");
        assertTrue(r.success(), "version should be correct after LR recovery");
    }
}
