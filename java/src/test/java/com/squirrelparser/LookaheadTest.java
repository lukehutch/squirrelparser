package com.squirrelparser;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Combinators.First;
import com.squirrelparser.Combinators.FollowedBy;
import com.squirrelparser.Combinators.NotFollowedBy;
import com.squirrelparser.Combinators.OneOrMore;
import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Combinators.Seq;
import com.squirrelparser.Combinators.ZeroOrMore;
import com.squirrelparser.Terminals.AnyChar;
import com.squirrelparser.Terminals.Char;
import com.squirrelparser.Terminals.CharRange;
import com.squirrelparser.Terminals.Str;

/**
 * Lookahead Operators Tests
 * Port of lookahead_test.dart
 */
class LookaheadTest {

    // =========================================================================
    // Direct Matching Tests (using parser.match() directly)
    // =========================================================================

    // FollowedBy (&) Tests

    @Test
    void testPositiveLookaheadSucceedsWhenPatternMatches() {
        Map<String, Clause> rules = Map.of(
            "Test", new FollowedBy(new Str("a"))
        );

        var parser = new Parser(rules, "abc");
        var result = parser.match(rules.get("Test"), 0, null);

        assertFalse(result.isMismatch());
        assertEquals(0, result.len()); // Lookahead doesn't consume
    }

    @Test
    void testPositiveLookaheadFailsWhenPatternDoesNotMatch() {
        Map<String, Clause> rules = Map.of(
            "Test", new FollowedBy(new Str("a"))
        );

        var parser = new Parser(rules, "b");
        var result = parser.match(rules.get("Test"), 0, null);

        assertTrue(result.isMismatch());
    }

    @Test
    void testPositiveLookaheadInSequence() {
        Map<String, Clause> rules = Map.of(
            "Test", new Seq(new Str("a"), new FollowedBy(new Str("b")))
        );

        // Should match 'a' and check for 'b', consuming only 'a'
        var parser = new Parser(rules, "abc");
        var result = parser.match(rules.get("Test"), 0, null);

        assertFalse(result.isMismatch());
        assertEquals(1, result.len()); // Only 'a' consumed
    }

    @Test
    void testPositiveLookaheadInSequenceFailsWhenNotFollowed() {
        Map<String, Clause> rules = Map.of(
            "Test", new Seq(new Str("a"), new FollowedBy(new Str("b")))
        );

        var parser = new Parser(rules, "ac");
        var result = parser.match(rules.get("Test"), 0, null);

        assertTrue(result.isMismatch()); // Fails because no 'b' after 'a'
    }

    @Test
    void testPositiveLookaheadWithContinuation() {
        Map<String, Clause> rules = Map.of(
            "Test", new Seq(new Str("a"), new FollowedBy(new Str("b")), new Str("b"))
        );

        // Should match 'a', check for 'b', then consume 'b'
        var parser = new Parser(rules, "abc");
        var result = parser.match(rules.get("Test"), 0, null);

        assertFalse(result.isMismatch());
        assertEquals(2, result.len()); // 'a' and 'b' consumed
    }

    @Test
    void testPositiveLookaheadAtEndOfInput() {
        Map<String, Clause> rules = Map.of(
            "Test", new Seq(new Str("a"), new FollowedBy(new Str("b")))
        );

        var parser = new Parser(rules, "a");
        var result = parser.match(rules.get("Test"), 0, null);

        assertTrue(result.isMismatch()); // No 'b' to look ahead to
    }

    @Test
    void testNestedPositiveLookaheads() {
        Map<String, Clause> rules = Map.of(
            "Test", new Seq(
                new FollowedBy(new FollowedBy(new Str("a"))),
                new Str("a")
            )
        );

        var parser = new Parser(rules, "a");
        var result = parser.match(rules.get("Test"), 0, null);

        assertFalse(result.isMismatch());
        assertEquals(1, result.len());
    }

    // NotFollowedBy (!) Tests

    @Test
    void testNegativeLookaheadSucceedsWhenPatternDoesNotMatch() {
        Map<String, Clause> rules = Map.of(
            "Test", new NotFollowedBy(new Str("a"))
        );

        var parser = new Parser(rules, "b");
        var result = parser.match(rules.get("Test"), 0, null);

        assertFalse(result.isMismatch());
        assertEquals(0, result.len()); // Lookahead doesn't consume
    }

    @Test
    void testNegativeLookaheadFailsWhenPatternMatches() {
        Map<String, Clause> rules = Map.of(
            "Test", new NotFollowedBy(new Str("a"))
        );

        var parser = new Parser(rules, "a");
        var result = parser.match(rules.get("Test"), 0, null);

        assertTrue(result.isMismatch());
    }

    @Test
    void testNegativeLookaheadInSequence() {
        Map<String, Clause> rules = Map.of(
            "Test", new Seq(new Str("a"), new NotFollowedBy(new Str("b")))
        );

        // Should match 'a' when NOT followed by 'b'
        var parser = new Parser(rules, "ac");
        var result = parser.match(rules.get("Test"), 0, null);

        assertFalse(result.isMismatch());
        assertEquals(1, result.len()); // Only 'a' consumed
    }

    @Test
    void testNegativeLookaheadInSequenceFailsWhenFollowed() {
        Map<String, Clause> rules = Map.of(
            "Test", new Seq(new Str("a"), new NotFollowedBy(new Str("b")))
        );

        var parser = new Parser(rules, "ab");
        var result = parser.match(rules.get("Test"), 0, null);

        assertTrue(result.isMismatch()); // Fails because 'a' IS followed by 'b'
    }

    @Test
    void testNegativeLookaheadWithContinuation() {
        Map<String, Clause> rules = Map.of(
            "Test", new Seq(new Str("a"), new NotFollowedBy(new Str("b")), new Str("c"))
        );

        // Should match 'a', check NOT 'b', then consume 'c'
        var parser = new Parser(rules, "ac");
        var result = parser.match(rules.get("Test"), 0, null);

        assertFalse(result.isMismatch());
        assertEquals(2, result.len()); // 'a' and 'c' consumed
    }

    @Test
    void testNegativeLookaheadAtEndOfInput() {
        Map<String, Clause> rules = Map.of(
            "Test", new Seq(new Str("a"), new NotFollowedBy(new Str("b")))
        );

        var parser = new Parser(rules, "a");
        var result = parser.match(rules.get("Test"), 0, null);

        assertFalse(result.isMismatch()); // No 'b' following, so succeeds
        assertEquals(1, result.len());
    }

    @Test
    void testNestedNegativeLookaheads() {
        Map<String, Clause> rules = Map.of(
            // !!"a" is the same as &"a"
            "Test", new Seq(
                new NotFollowedBy(new NotFollowedBy(new Str("a"))),
                new Str("a")
            )
        );

        var parser = new Parser(rules, "a");
        var result = parser.match(rules.get("Test"), 0, null);

        assertFalse(result.isMismatch());
        assertEquals(1, result.len());
    }

    // Mixed Lookaheads Tests

    @Test
    void testPositiveThenNegativeLookahead() {
        Map<String, Clause> rules = Map.of(
            "Test", new Seq(
                new FollowedBy(new CharRange("a", "z")),
                new NotFollowedBy(new Str("x")),
                new CharRange("a", "z")
            )
        );

        // Should match any lowercase letter except 'x'
        var parser = new Parser(rules, "a");
        var result = parser.match(rules.get("Test"), 0, null);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "x");
        result = parser.match(rules.get("Test"), 0, null);
        assertTrue(result.isMismatch());

        parser = new Parser(rules, "A");
        result = parser.match(rules.get("Test"), 0, null);
        assertTrue(result.isMismatch());
    }

    @Test
    void testLookaheadInChoice() {
        Map<String, Clause> rules = Map.of(
            "Test", new First(
                new Seq(new FollowedBy(new Str("a")), new Str("a")),
                new Seq(new FollowedBy(new Str("b")), new Str("b"))
            )
        );

        var parser = new Parser(rules, "a");
        var result = parser.match(rules.get("Test"), 0, null);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());

        parser = new Parser(rules, "b");
        result = parser.match(rules.get("Test"), 0, null);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());

        parser = new Parser(rules, "c");
        result = parser.match(rules.get("Test"), 0, null);
        assertTrue(result.isMismatch());
    }

    @Test
    void testLookaheadWithRepetition() {
        Map<String, Clause> rules = Map.of(
            "Test", new ZeroOrMore(new Seq(
                new NotFollowedBy(new Str(".")),
                new CharRange("a", "z")
            ))
        );

        // Match lowercase letters until '.'
        var parser = new Parser(rules, "abc.def");
        var result = parser.match(rules.get("Test"), 0, null);
        assertFalse(result.isMismatch());
        assertEquals(3, result.len()); // 'abc'

        parser = new Parser(rules, ".abc");
        result = parser.match(rules.get("Test"), 0, null);
        assertFalse(result.isMismatch());
        assertEquals(0, result.len()); // Stops immediately at '.'
    }

    // Lookahead with References Tests

    @Test
    void testPositiveLookaheadWithRuleReference() {
        Map<String, Clause> rules = Map.of(
            "Digit", new CharRange("0", "9"),
            "Test", new Seq(
                new FollowedBy(new Ref("Digit")),
                new Ref("Digit")
            )
        );

        var parser = new Parser(rules, "5");
        var result = parser.match(rules.get("Test"), 0, null);

        assertFalse(result.isMismatch());
        assertEquals(1, result.len());
    }

    @Test
    void testNegativeLookaheadWithRuleReference() {
        Map<String, Clause> rules = Map.of(
            "Digit", new CharRange("0", "9"),
            "Test", new Seq(
                new NotFollowedBy(new Ref("Digit")),
                new CharRange("a", "z")
            )
        );

        var parser = new Parser(rules, "a");
        var result = parser.match(rules.get("Test"), 0, null);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "5");
        result = parser.match(rules.get("Test"), 0, null);
        assertTrue(result.isMismatch());
    }

    // =========================================================================
    // Integration with parse() Tests
    // =========================================================================

    @Test
    void testLookaheadWithFullInputConsumption() {
        Map<String, Clause> rules = Map.of(
            "Test", new Seq(new Str("a"), new FollowedBy(new Str("b")), new Str("b"))
        );

        // Should match and consume all input
        var parser = new Parser(rules, "ab");
        var result = parser.parse("Test");

        assertNotNull(result);
        assertEquals(2, result.len()); // Both 'a' and 'b' consumed
    }

    @Test
    void testNegativeLookaheadWithFullInputConsumption() {
        Map<String, Clause> rules = Map.of(
            "Test", new Seq(new Str("a"), new NotFollowedBy(new Str("b")), new Str("c"))
        );

        var parser = new Parser(rules, "ac");
        var result = parser.parse("Test");

        assertNotNull(result);
        assertEquals(2, result.len()); // 'a' and 'c' consumed
    }

    @Test
    void testIdentifierParserWithLookaheadValid() {
        // Parse identifiers that don't start with a digit
        Map<String, Clause> rules = Map.of(
            "Identifier", new Seq(
                new NotFollowedBy(new CharRange("0", "9")),
                new OneOrMore(new First(
                    new CharRange("a", "z"),
                    new CharRange("A", "Z"),
                    new CharRange("0", "9"),
                    new Char("_")
                ))
            )
        );

        // Valid identifier (all input consumed)
        var parser = new Parser(rules, "abc123");
        var result = parser.parse("Identifier");
        assertNotNull(result);
        assertEquals(6, result.len());
    }

    @Test
    void testIdentifierParserWithLookaheadUsingMatch() {
        // Parse identifiers that don't start with a digit
        Map<String, Clause> rules = Map.of(
            "Identifier", new Seq(
                new NotFollowedBy(new CharRange("0", "9")),
                new OneOrMore(new First(
                    new CharRange("a", "z"),
                    new CharRange("A", "Z"),
                    new CharRange("0", "9"),
                    new Char("_")
                ))
            )
        );

        // Test with match to avoid recovery
        var parser = new Parser(rules, "123abc");
        var result = parser.match(rules.get("Identifier"), 0, null);
        assertTrue(result.isMismatch()); // Starts with digit, should fail
    }

    @Test
    void testKeywordVsIdentifierWithLookahead() {
        // Parse 'if' only when not followed by alphanumeric (i.e., as keyword)
        Map<String, Clause> rules = Map.of(
            "Keyword", new Seq(
                new Str("if"),
                new NotFollowedBy(new First(
                    new CharRange("a", "z"),
                    new CharRange("A", "Z"),
                    new CharRange("0", "9"),
                    new Char("_")
                ))
            )
        );

        // Valid keyword (all input consumed)
        var parser = new Parser(rules, "if");
        var result = parser.parse("Keyword");
        assertFalse(result.isMismatch()); // 'if' as keyword
        assertEquals(2, result.len());

        // Invalid - 'ifx' is not just 'if'
        parser = new Parser(rules, "ifx");
        result = parser.parse("Keyword");
        // Total failure returns SyntaxError spanning entire input
        assertTrue(result instanceof SyntaxError);
    }

    @Test
    void testCommentParserWithLookahead() {
        // Parse // style comments until end of line
        Map<String, Clause> rules = Map.of(
            "Comment", new Seq(
                new Str("//"),
                new ZeroOrMore(new Seq(
                    new NotFollowedBy(new Char("\n")),
                    new AnyChar()
                )),
                new Char("\n")
            )
        );

        var parser = new Parser(rules, "//hello world\n");
        var result = parser.parse("Comment");
        assertFalse(result.isMismatch());
        assertEquals(14, result.len()); // All input consumed
    }

    @Test
    void testStringLiteralParserWithLookahead() {
        // Parse string literals with escape sequences
        Map<String, Clause> rules = Map.of(
            "String", new Seq(
                new Char("\""),
                new ZeroOrMore(new First(
                    new Seq(new Str("\\"), new AnyChar()), // Escape sequence
                    new Seq(new NotFollowedBy(new Char("\"")), new AnyChar()) // Non-quote char
                )),
                new Char("\"")
            )
        );

        var parser = new Parser(rules, "\"hello\"");
        var result = parser.parse("String");
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "\"hello\\\"world\"");
        result = parser.parse("String");
        assertFalse(result.isMismatch());
    }
}
