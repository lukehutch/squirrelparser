package com.squirrelparser;

import static com.squirrelparser.TestUtils.parse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Terminals.Str;

/**
 * FIRST ALTERNATIVE SELECTION TESTS (FIX #2 Verification)
 * Port of first_alternative_selection_test.dart
 */
class FirstAlternativeSelectionTest {

    @Test
    void testFIRST01_allAlternativesFailCleanly() {
        var result = parse(Map.of(
            "S", new First(new Str("a"), new Str("b"), new Str("c"))
        ), "x");
        assertFalse(result.success(), "should fail (no alternative matches)");
    }

    @Test
    void testFIRST02_firstNeedsRecoverySecondClean() {
        var result = parse(Map.of(
            "S", new First(
                new Seq(new Str("a"), new Str("b")),
                new Str("c")
            )
        ), "aXb");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "first alternative chosen (longer despite error)");
    }

    @Test
    void testFIRST03_allAlternativesNeedRecovery() {
        var result = parse(Map.of(
            "S", new First(
                new Seq(new Str("a"), new Str("b"), new Str("c")),
                new Seq(new Str("a"), new Str("y"), new Str("z"))
            )
        ), "aXbc");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should choose first alternative (matches with recovery)");
    }

    @Test
    void testFIRST04_longerWithErrorVsShorterClean() {
        var result = parse(Map.of(
            "S", new First(
                new Seq(new Str("a"), new Str("b"), new Str("c")),
                new Str("a")
            )
        ), "aXbc");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should choose first (longer despite error)");
    }

    @Test
    void testFIRST05_sameLengthFewerErrorsWins() {
        var result = parse(Map.of(
            "S", new First(
                new Seq(new Str("a"), new Str("b"), new Str("c"), new Str("d")),
                new Seq(new Str("a"), new Str("b"), new Str("c"))
            )
        ), "aXbc");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should choose second (fewer errors)");
    }

    @Test
    void testFIRST06_multipleCleanAlternatives() {
        var result = parse(Map.of(
            "S", new First(
                new Str("abc"),
                new Str("abc"),
                new Str("ab")
            )
        ), "abc");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors (clean match)");
    }

    @Test
    void testFIRST07_preferLongerCleanOverShorterClean() {
        var result = parse(Map.of(
            "S", new First(new Str("abc"), new Str("ab"))
        ), "abc");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testFIRST08_fallbackAfterAllLongerFail() {
        var result = parse(Map.of(
            "S", new First(
                new Seq(new Str("x"), new Str("y"), new Str("z")),
                new Str("a")
            )
        ), "a");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors (clean second alternative)");
    }

    @Test
    void testFIRST09_leftRecursiveAlternative() {
        var result = parse(Map.of(
            "E", new First(
                new Seq(new Ref("E"), new Str("+"), new Str("n")),
                new Str("n")
            )
        ), "n+Xn", "E");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should have 1 error");
    }

    @Test
    void testFIRST10_nestedFirst() {
        var result = parse(Map.of(
            "S", new First(
                new First(new Str("a"), new Str("b")),
                new Str("c")
            )
        ), "b");
        assertTrue(result.success(), "should succeed");
        assertEquals(0, result.errorCount(), "should have 0 errors");
    }

    @Test
    void testFIRST11_allAlternativesIncomplete() {
        var result = parse(Map.of(
            "S", new First(new Str("a"), new Str("b"))
        ), "aXXX");
        assertFalse(result.success(), "should fail (no alternative consumes full input)");
    }

    @Test
    void testFIRST12_recoveryWithComplexAlternatives() {
        var result = parse(Map.of(
            "S", new First(
                new Seq(new OneOrMore(new Str("x")), new Str("y")),
                new Seq(new OneOrMore(new Str("a")), new Str("b"))
            )
        ), "xxxXy");
        assertTrue(result.success(), "should succeed");
        assertEquals(1, result.errorCount(), "should choose first alternative");
    }
}
