package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Optional;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.Str;

/**
 * SECTION 11: STRESS TESTS (20 tests)
 * Port of stress_test.dart
 */
class StressTest {

    @Test
    void testST01_1000Clean() {
        var r = parse(Map.of("S", new OneOrMore(new Str("ab"))), "ab".repeat(500));
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST02_1000Err() {
        var r = parse(Map.of("S", new OneOrMore(new Str("ab"))), "ab".repeat(250) + "XX" + "ab".repeat(249));
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
    }

    @Test
    void testST03_100Groups() {
        var r = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), "(xx)".repeat(100));
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST04_100GroupsErr() {
        var input = IntStream.range(0, 100)
            .mapToObj(i -> i % 10 == 5 ? "(xZx)" : "(xx)")
            .collect(Collectors.joining());
        var r = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), input);
        assertTrue(r.success(), "should succeed");
        assertEquals(10, r.errorCount(), "should have 10 errors");
    }

    @Test
    void testST05_DeepNesting() {
        var r = parse(Map.of(
            "S", new Seq(new Str("("), new Ref("A"), new Str(")")),
            "A", new First(
                new Seq(new Str("("), new Ref("A"), new Str(")")),
                new Str("x")
            )
        ), "(".repeat(15) + "x" + ")".repeat(15));
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST06_50Alts() {
        var alts = IntStream.range(0, 50)
            .mapToObj(i -> new Str("opt" + i))
            .toArray(Clause[]::new);
        var allAlts = new Clause[alts.length + 1];
        System.arraycopy(alts, 0, allAlts, 0, alts.length);
        allAlts[alts.length] = new Str("match");
        var r = parse(Map.of("S", new First(allAlts)), "match");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST07_500Chars() {
        var r = parse(Map.of("S", new OneOrMore(new Str("x"))), "x".repeat(500));
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST08_500Plus5Err() {
        var input = new StringBuilder("x".repeat(100));
        for (int i = 0; i < 5; i++) {
            input.append("Z").append("x".repeat(99));
        }
        var r = parse(Map.of("S", new OneOrMore(new Str("x"))), input.toString());
        assertTrue(r.success(), "should succeed");
        assertEquals(5, r.errorCount(), "should have 5 errors");
    }

    @Test
    void testST09_100Seq() {
        var clauses = IntStream.range(0, 100)
            .mapToObj(i -> new Str("x"))
            .toArray(Clause[]::new);
        var r = parse(Map.of("S", new Seq(clauses)), "x".repeat(100));
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST10_50Optional() {
        var clauses = new Clause[51];
        for (int i = 0; i < 50; i++) {
            clauses[i] = new Optional(new Str("x"));
        }
        clauses[50] = new Str("!");
        var r = parse(Map.of("S", new Seq(clauses)), "x".repeat(25) + "!");
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST11_NestedRep() {
        var r = parse(Map.of("S", new OneOrMore(new OneOrMore(new Str("x")))), "x".repeat(200));
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST12_LongErrSpan() {
        var r = parse(Map.of("S", new OneOrMore(new Str("ab"))), "ab" + "X".repeat(200) + "ab");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
    }

    @Test
    void testST13_ManyShortErr() {
        var input = "abX".repeat(30) + "ab";
        var r = parse(Map.of("S", new OneOrMore(new Str("ab"))), input);
        assertTrue(r.success(), "should succeed");
        assertEquals(30, r.errorCount(), "should have 30 errors");
    }

    @Test
    void testST14_2000Clean() {
        var r = parse(Map.of("S", new OneOrMore(new Str("x"))), "x".repeat(2000));
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST15_2000Err() {
        var r = parse(Map.of("S", new OneOrMore(new Str("x"))), "x".repeat(1000) + "ZZ" + "x".repeat(998));
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
    }

    @Test
    void testST16_200Groups() {
        var r = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), "(xx)".repeat(200));
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST17_200Groups20Err() {
        var input = IntStream.range(0, 200)
            .mapToObj(i -> i % 10 == 0 ? "(xZx)" : "(xx)")
            .collect(Collectors.joining());
        var r = parse(Map.of(
            "S", new OneOrMore(new Seq(new Str("("), new OneOrMore(new Str("x")), new Str(")")))
        ), input);
        assertTrue(r.success(), "should succeed");
        assertEquals(20, r.errorCount(), "should have 20 errors");
    }

    @Test
    void testST18_50Errors() {
        var input = "abZ".repeat(50) + "ab";
        var r = parse(Map.of("S", new OneOrMore(new Str("ab"))), input);
        assertTrue(r.success(), "should succeed");
        assertEquals(50, r.errorCount(), "should have 50 errors");
    }

    @Test
    void testST19_DeepL5() {
        var r = parse(Map.of(
            "S", new Seq(
                new Str("1"),
                new Seq(
                    new Str("2"),
                    new Seq(
                        new Str("3"),
                        new Seq(
                            new Str("4"),
                            new Seq(new Str("5"), new OneOrMore(new Str("x")), new Str("5")),
                            new Str("4")
                        ),
                        new Str("3")
                    ),
                    new Str("2")
                ),
                new Str("1")
            )
        ), "12345xZx54321");
        assertTrue(r.success(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skipped().contains("Z"), "should skip Z");
    }

    @Test
    void testST20_VeryDeepNest() {
        var r = parse(Map.of(
            "S", new Seq(new Str("("), new Ref("A"), new Str(")")),
            "A", new First(
                new Seq(new Str("("), new Ref("A"), new Str(")")),
                new Str("x")
            )
        ), "(".repeat(20) + "x" + ")".repeat(20));
        assertTrue(r.success(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }
}
