package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashMap;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.Str;

/**
 * COMPREHENSIVE FIX TESTS (10 tests)
 * Port of fix_comprehensive_test.dart
 */
class FixComprehensiveTest {

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

    // Fix #3: Ref transparency - Ref should not have independent memoization
    @Test
    void testFIX3_01RefTransparencyLRReexpansion() {
        var g = grammar(
            rule("S", new Seq(new Ref("E"), new Str(";"))),
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            ))
        );
        var r = parse(g, "n+Xn;");
        assertTrue(r.success(), "Ref should allow LR re-expansion during recovery");
        assertEquals(1, r.errorCount(), "should skip X");
    }

    // Fix #4: Terminal skip sanity - single-char vs multi-char
    @Test
    void testFIX4_01SingleCharSkipJunk() {
        var g = grammar(
            rule("S", new Seq(new Str("a"), new Str("b"), new Str("c")))
        );
        var r = parse(g, "aXXbc");
        assertTrue(r.success(), "should skip junk XX");
        assertEquals(1, r.errorCount(), "one skip");
        assertTrue(r.skipped().contains("XX"));
    }

    @Test
    void testFIX4_02SingleCharNoSkipContainingTerminal() {
        var g = grammar(
            rule("S", new Seq(new Str("a"), new Str("b"), new Str("c")))
        );
        var r = parse(g, "aXbYc");
        assertTrue(r.success(), "should recover with multiple skips");
    }

    @Test
    void testFIX4_03MultiCharAtomicTerminal() {
        var g = grammar(
            rule("S", new Ref("E")),
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+n")),
                new Str("n")
            ))
        );
        var r = parse(g, "n+Xn+n");
        assertFalse(r.success(), "X breaks atomic +n terminal");
    }

    @Test
    void testFIX4_04MultiCharExactSkipOk() {
        var g = grammar(
            rule("S", new Seq(new Str("ab"), new Str("cd")))
        );
        var r = parse(g, "abXYcd");
        assertTrue(r.success(), "can skip 2 chars for 2-char terminal");
        assertEquals(1, r.errorCount(), "one skip");
    }

    // Fix #5: Don't skip content containing next expected terminal
    @Test
    void testFIX5_01NoSkipContainingNextTerminal() {
        var g = grammar(
            rule("S", new Seq(new Ref("E"), new Str(";"), new Ref("E"))),
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            ))
        );
        var r = parse(g, "n+Xn;n+n+n");
        assertTrue(r.success(), "should recover");
        assertEquals(1, r.errorCount(), "only skip X in first E, not consume ;n");
    }

    @Test
    void testFIX5_02SkipPureJunkOk() {
        var g = grammar(
            rule("S", new Seq(new Str("+"), new Str("n")))
        );
        var r = parse(g, "+XXn");
        assertTrue(r.success(), "should skip XX");
        assertEquals(1, r.errorCount(), "one skip");
        assertTrue(r.skipped().contains("XX"));
    }

    // Combined fixes: complex scenarios
    @Test
    void testCOMBINED01LRWithSkipAndDelete() {
        var g = grammar(
            rule("S", new Seq(new Ref("E"))),
            rule("E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            ))
        );
        var r = parse(g, "n+Xn+Yn");
        assertTrue(r.success(), "should handle multiple errors in LR");
    }

    @Test
    void testCOMBINED02FirstPrefersLongerWithErrors() {
        var g = grammar(
            rule("S", new First(
                new Seq(new Str("a"), new Str("b"), new Str("c")),
                new Str("a")
            ))
        );
        var r = parse(g, "aXbc");
        assertTrue(r.success(), "should choose longer alternative");
        assertEquals(1, r.errorCount(), "skip X");
    }

    @Test
    void testCOMBINED03NestedSeqRecovery() {
        var g = grammar(
            rule("S", new Seq(new Ref("A"), new Str(";"), new Ref("B"))),
            rule("A", new Seq(new Str("a"), new Str("x"))),
            rule("B", new Seq(new Str("b"), new Str("y")))
        );
        var r = parse(g, "aXx;bYy");
        assertTrue(r.success(), "nested recovery should work");
        assertEquals(2, r.errorCount(), "skip X and Y");
    }
}
