package com.squirrelparser.metagrammar;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Clause;
import com.squirrelparser.MatchResult;
import com.squirrelparser.MetaGrammar;
import com.squirrelparser.Parser;
import com.squirrelparser.SyntaxError;

/**
 * MetaGrammar - Basic Syntax Tests
 * Port of basic_syntax_test.dart
 */
class BasicSyntaxTest {

    @Test
    void testSimpleRuleWithStringLiteral() {
        String grammar = """
            Hello <- "hello";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        assertTrue(rules.containsKey("Hello"));

        Parser parser = new Parser(rules, "hello");
        MatchResult result = parser.parse("Hello");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(5, result.len());
    }

    @Test
    void testRuleWithCharacterLiteral() {
        String grammar = """
            A <- 'a';
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "a");
        MatchResult result = parser.parse("A");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());
    }

    @Test
    void testSequenceOfLiterals() {
        String grammar = """
            AB <- "a" "b";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "ab");
        MatchResult result = parser.parse("AB");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(2, result.len());
    }

    @Test
    void testChoiceBetweenAlternatives() {
        String grammar = """
            AorB <- "a" / "b";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "a");
        MatchResult result = parser.parse("AorB");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());

        parser = new Parser(rules, "b");
        result = parser.parse("AorB");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());
    }

    @Test
    void testZeroOrMoreRepetition() {
        String grammar = """
            As <- "a"*;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "");
        MatchResult result = parser.parse("As");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(0, result.len());

        parser = new Parser(rules, "aaa");
        result = parser.parse("As");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(3, result.len());
    }

    @Test
    void testOneOrMoreRepetition() {
        String grammar = """
            As <- "a"+;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "");
        MatchResult result = parser.parse("As");
        // Total failure on empty input returns SyntaxError spanning all input
        assertTrue(result instanceof SyntaxError);

        parser = new Parser(rules, "aaa");
        result = parser.parse("As");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(3, result.len());
    }

    @Test
    void testOptional() {
        String grammar = """
            OptA <- "a"?;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "");
        MatchResult result = parser.parse("OptA");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(0, result.len());

        parser = new Parser(rules, "a");
        result = parser.parse("OptA");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());
    }

    @Test
    void testPositiveLookahead() {
        String grammar = """
            AFollowedByB <- "a" &"b" "b";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "ab");
        MatchResult result = parser.parse("AFollowedByB");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(2, result.len()); // Both 'a' and 'b' consumed

        parser = new Parser(rules, "ac");
        result = parser.parse("AFollowedByB");
        // Total failure returns SyntaxError spanning entire input
        assertTrue(result instanceof SyntaxError);
    }

    @Test
    void testNegativeLookahead() {
        String grammar = """
            ANotFollowedByB <- "a" !"b" "c";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "ac");
        MatchResult result = parser.parse("ANotFollowedByB");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(2, result.len()); // Both 'a' and 'c' consumed

        parser = new Parser(rules, "ab");
        result = parser.parse("ANotFollowedByB");
        // Total failure returns SyntaxError spanning entire input
        assertTrue(result instanceof SyntaxError);
    }

    @Test
    void testAnyCharacter() {
        String grammar = """
            AnyOne <- .;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "x");
        MatchResult result = parser.parse("AnyOne");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());

        parser = new Parser(rules, "9");
        result = parser.parse("AnyOne");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());
    }

    @Test
    void testGroupingWithParentheses() {
        String grammar = """
            Group <- ("a" / "b") "c";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "ac");
        MatchResult result = parser.parse("Group");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(2, result.len());

        parser = new Parser(rules, "bc");
        result = parser.parse("Group");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(2, result.len());
    }
}
