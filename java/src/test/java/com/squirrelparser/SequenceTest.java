package com.squirrelparser;

import static com.squirrelparser.TestUtils.countDeletions;
import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.Str;

/**
 * SECTION 7: SEQUENCE COMPREHENSIVE (20 tests)
 * Port of sequence_test.dart
 */
class SequenceTest {

    @Test
    void testS01_2elem() {
        var result = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("b"))
        ), "ab");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testS02_3elem() {
        var result = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("b"), new Str("c"))
        ), "abc");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testS03_5elem() {
        var result = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("b"), new Str("c"), new Str("d"), new Str("e"))
        ), "abcde");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testS04_insertMid() {
        var result = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("b"), new Str("c"))
        ), "aXXbc");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("XX"), "should skip XX");
    }

    @Test
    void testS05_insertEnd() {
        var result = parse(Map.of(
            "S", new Seq(new Str("a"), new Str("b"), new Str("c"))
        ), "abXXc");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("XX"), "should skip XX");
    }

    @Test
    void testS06_delMid() {
        // Cannot delete grammar elements mid-parse (Fix #8 - Visibility Constraint)
        // Input "ac" with grammar "a" "b" "c" would require deleting "b" at position 1
        // Position 1 is not EOF (still have "c" to parse), so this violates constraints
        var parser = new Parser(Map.of(
            "S", new Seq(new Str("a"), new Str("b"), new Str("c"))
        ), "ac");
        var matchResult = parser.parse("S");
        // Should fail - cannot delete "b" mid-parse
        // With spanning invariant: failure returns SyntaxError (or partial match with trailing SyntaxError)
        assertTrue(matchResult instanceof SyntaxError,
            "should fail (mid-parse grammar deletion violates Visibility Constraint)");
    }

    @Test
    void testS07_delEnd() {
        var parser = new Parser(Map.of(
            "S", new Seq(new Str("a"), new Str("b"), new Str("c"))
        ), "ab");
        var matchResult = parser.parse("S");
        assertTrue(matchResult != null && !matchResult.isMismatch(),
            "should succeed");
        assertEquals(1, countDeletions(matchResult),
            "should have 1 deletion");
    }

    @Test
    void testS08_nestedClean() {
        var result = parse(Map.of(
            "S", new Seq(
                new Seq(new Str("a"), new Str("b")),
                new Str("c")
            )
        ), "abc");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testS09_nestedInsert() {
        var result = parse(Map.of(
            "S", new Seq(
                new Seq(new Str("a"), new Str("b")),
                new Str("c")
            )
        ), "aXbc");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
        assertTrue(result.skipped().contains("X"), "should skip X");
    }

    @Test
    void testS10_longSeqClean() {
        var clauses = "abcdefghijklmnop".chars()
            .mapToObj(c -> new Str(String.valueOf((char) c)))
            .toArray(Clause[]::new);
        var result = parse(Map.of("S", new Seq(clauses)), "abcdefghijklmnop");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }
}
