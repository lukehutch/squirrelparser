package com.squirrelparser;

import static com.squirrelparser.TestUtils.testParse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class FixComprehensiveTest {

    // Fix #3: Ref transparency - Ref should not have independent memoization
    @Test
    void FIX3_01_ref_transparency_lr_reexpansion() {
        // During recovery, Ref should allow LR to re-expand
        var grammar = """
            S <- E ";" ;
            E <- E "+" "n" / "n" ;
            """;
        var result = testParse(grammar, "n+Xn;");
        assertTrue(result.ok(), "Ref should allow LR re-expansion during recovery");
        assertEquals(1, result.errorCount(), "should skip X");
    }

    // Fix #4: Terminal skip sanity - single-char vs multi-char
    @Test
    void FIX4_01_single_char_skip_junk() {
        // Single-char terminal can skip arbitrary junk
        var grammar = "S <- \"a\" \"b\" \"c\" ;";
        var result = testParse(grammar, "aXXbc");
        assertTrue(result.ok(), "should skip junk XX");
        assertEquals(1, result.errorCount(), "one skip");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("XX")));
    }

    @Test
    void FIX4_02_single_char_no_skip_containing_terminal() {
        // Single-char terminal should NOT skip if junk contains the terminal
        var grammar = "S <- \"a\" \"b\" \"c\" ;";
        var result = testParse(grammar, "aXbYc");
        // This might succeed by skipping X, matching b, skipping Y (2 errors)
        // The key is it shouldn't skip "Xb" as one unit
        assertTrue(result.ok(), "should recover with multiple skips");
    }

    @Test
    void FIX4_03_multi_char_atomic_terminal() {
        // Multi-char terminal is atomic - can't skip more than its length
        // Grammar only matches 'n', rest captured as trailing error
        var grammar = """
            S <- E ;
            E <- E "+n" / "n" ;
            """;
        var result = testParse(grammar, "n+Xn+n");
        assertTrue(result.ok(), "matches n, rest is trailing error");
        assertEquals(1, result.errorCount(), "should have 1 error (trailing +Xn+n)");
    }

    @Test
    void FIX4_04_multi_char_exact_skip_ok() {
        // Multi-char terminal can skip exactly its length if needed
        var grammar = "S <- \"ab\" \"cd\" ;";
        var result = testParse(grammar, "abXYcd");
        assertTrue(result.ok(), "can skip 2 chars for 2-char terminal");
        assertEquals(1, result.errorCount(), "one skip");
    }

    // Fix #5: Don't skip content containing next expected terminal
    @Test
    void FIX5_01_no_skip_containing_next_terminal() {
        // During recovery, don't skip content that includes next terminal
        var grammar = """
            S <- E ";" E ;
            E <- E "+" "n" / "n" ;
            """;
        var result = testParse(grammar, "n+Xn;n+n+n");
        assertTrue(result.ok(), "should recover");
        assertEquals(1, result.errorCount(), "only skip X in first E, not consume ;n");
    }

    @Test
    void FIX5_02_skip_pure_junk_ok() {
        // Can skip junk that doesn't contain next terminal
        var grammar = "S <- \"+\" \"n\" ;";
        var result = testParse(grammar, "+XXn");
        assertTrue(result.ok(), "should skip XX");
        assertEquals(1, result.errorCount(), "one skip");
        assertTrue(result.skippedStrings().stream().anyMatch(s -> s.contains("XX")));
    }

    // Combined fixes: complex scenarios
    @Test
    void COMBINED_01_lr_with_skip_and_delete() {
        // LR expansion + recovery with both skip and delete
        var grammar = """
            S <- E ;
            E <- E "+" "n" / "n" ;
            """;
        var result = testParse(grammar, "n+Xn+Yn");
        assertTrue(result.ok(), "should handle multiple errors in LR");
    }

    @Test
    void COMBINED_02_first_prefers_longer_with_errors() {
        // First should prefer longer match even if it has more errors
        var grammar = """
            S <- "a" "b" "c" / "a" ;
            """;
        var result = testParse(grammar, "aXbc");
        assertTrue(result.ok(), "should choose longer alternative");
        assertEquals(1, result.errorCount(), "skip X");
        // Result should be "abc" not just "a"
    }

    @Test
    void COMBINED_03_nested_seq_recovery() {
        // Nested sequences with recovery at different levels
        var grammar = """
            S <- A ";" B ;
            A <- "a" "x" ;
            B <- "b" "y" ;
            """;
        var result = testParse(grammar, "aXx;bYy");
        assertTrue(result.ok(), "nested recovery should work");
        assertEquals(2, result.errorCount(), "skip X and Y");
    }
}
