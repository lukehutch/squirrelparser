package com.squirrelparser;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.stream.Collectors;
import java.util.stream.IntStream;

import org.junit.jupiter.api.Test;

/**
 * SECTION 11: STRESS TESTS (20 tests)
 */
class ParserStressTest {

    @Test
    void testST01_1000Clean() {
        var r = TestUtils.testParse("S <- \"ab\"+ ;", "ab".repeat(500));
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST02_1000Err() {
        var r = TestUtils.testParse("S <- \"ab\"+ ;", "ab".repeat(250) + "XX" + "ab".repeat(249));
        assertTrue(r.ok(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
    }

    @Test
    void testST03_100Groups() {
        String grammar = "S <- (\"(\" \"x\"+ \")\")+ ;";
        var r = TestUtils.testParse(grammar, "(xx)".repeat(100));
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST04_100GroupsErr() {
        String input = IntStream.range(0, 100)
            .mapToObj(i -> i % 10 == 5 ? "(xZx)" : "(xx)")
            .collect(Collectors.joining());
        String grammar = "S <- (\"(\" \"x\"+ \")\")+ ;";
        var r = TestUtils.testParse(grammar, input);
        assertTrue(r.ok(), "should succeed");
        assertEquals(10, r.errorCount(), "should have 10 errors");
    }

    @Test
    void testST05_DeepNesting() {
        String grammar = """
            S <- "(" A ")" ;
            A <- "(" A ")" / "x" ;
        """;
        var r = TestUtils.testParse(grammar, "(".repeat(15) + "x" + ")".repeat(15));
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST06_50Alts() {
        String alts = IntStream.range(0, 50)
            .mapToObj(i -> "\"opt" + i + "\"")
            .collect(Collectors.joining(" / "));
        String grammar = "S <- " + alts + " / \"match\" ;";
        var r = TestUtils.testParse(grammar, "match");
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST07_500Chars() {
        var r = TestUtils.testParse("S <- \"x\"+ ;", "x".repeat(500));
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST08_500Plus5Err() {
        StringBuilder input = new StringBuilder("x".repeat(100));
        for (int i = 0; i < 5; i++) {
            input.append("Z").append("x".repeat(99));
        }
        var r = TestUtils.testParse("S <- \"x\"+ ;", input.toString());
        assertTrue(r.ok(), "should succeed");
        assertEquals(5, r.errorCount(), "should have 5 errors");
    }

    @Test
    void testST09_100Seq() {
        @SuppressWarnings("unused")
        String elems = IntStream.range(0, 100)
            .mapToObj(i -> "\"x\"")
            .collect(Collectors.joining(" "));
        String grammar = "S <- " + elems + " ;";
        var r = TestUtils.testParse(grammar, "x".repeat(100));
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST10_50Optional() {
        @SuppressWarnings("unused")
        String elems = IntStream.range(0, 50)
            .mapToObj(i -> "\"x\"?")
            .collect(Collectors.joining(" "));
        String grammar = "S <- " + elems + " \"!\" ;";
        var r = TestUtils.testParse(grammar, "x".repeat(25) + "!");
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST11_NestedRep() {
        String grammar = "S <- (\"x\"+)+ ;";
        var r = TestUtils.testParse(grammar, "x".repeat(200));
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST12_LongErrSpan() {
        var r = TestUtils.testParse("S <- \"ab\"+ ;", "ab" + "X".repeat(200) + "ab");
        assertTrue(r.ok(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
    }

    @Test
    void testST13_ManyShortErr() {
        @SuppressWarnings("unused")
        String input = IntStream.range(0, 30)
            .mapToObj(i -> "abX")
            .collect(Collectors.joining()) + "ab";
        var r = TestUtils.testParse("S <- \"ab\"+ ;", input);
        assertTrue(r.ok(), "should succeed");
        assertEquals(30, r.errorCount(), "should have 30 errors");
    }

    @Test
    void testST14_2000Clean() {
        var r = TestUtils.testParse("S <- \"x\"+ ;", "x".repeat(2000));
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST15_2000Err() {
        var r = TestUtils.testParse("S <- \"x\"+ ;", "x".repeat(1000) + "ZZ" + "x".repeat(998));
        assertTrue(r.ok(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
    }

    @Test
    void testST16_200Groups() {
        String grammar = "S <- (\"(\" \"x\"+ \")\")+ ;";
        var r = TestUtils.testParse(grammar, "(xx)".repeat(200));
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }

    @Test
    void testST17_200Groups20Err() {
        String input = IntStream.range(0, 200)
            .mapToObj(i -> i % 10 == 0 ? "(xZx)" : "(xx)")
            .collect(Collectors.joining());
        String grammar = "S <- (\"(\" \"x\"+ \")\")+ ;";
        var r = TestUtils.testParse(grammar, input);
        assertTrue(r.ok(), "should succeed");
        assertEquals(20, r.errorCount(), "should have 20 errors");
    }

    @Test
    void testST18_50Errors() {
        @SuppressWarnings("unused")
        String input = IntStream.range(0, 50)
            .mapToObj(i -> "abZ")
            .collect(Collectors.joining()) + "ab";
        var r = TestUtils.testParse("S <- \"ab\"+ ;", input);
        assertTrue(r.ok(), "should succeed");
        assertEquals(50, r.errorCount(), "should have 50 errors");
    }

    @Test
    void testST19_DeepL5() {
        String grammar = """
            S <- "1" (
              "2" (
                "3" (
                  "4" (
                    "5" "x"+ "5"
                  ) "4"
                ) "3"
              ) "2"
            ) "1" ;
        """;
        var r = TestUtils.testParse(grammar, "12345xZx54321");
        assertTrue(r.ok(), "should succeed");
        assertEquals(1, r.errorCount(), "should have 1 error");
        assertTrue(r.skippedStrings().contains("Z"), "should skip Z");
    }

    @Test
    void testST20_VeryDeepNest() {
        String grammar = """
            S <- "(" A ")" ;
            A <- "(" A ")" / "x" ;
        """;
        var r = TestUtils.testParse(grammar, "(".repeat(20) + "x" + ")".repeat(20));
        assertTrue(r.ok(), "should succeed");
        assertEquals(0, r.errorCount(), "should have 0 errors");
    }
}
