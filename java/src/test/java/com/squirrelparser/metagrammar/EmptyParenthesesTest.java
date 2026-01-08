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

/**
 * MetaGrammar - Empty Parentheses (Nothing) Tests
 */
class EmptyParenthesesTest {

    @Test
    void testEmptyParenthesesMatchesEmptyString() {
        String grammar = """
            Empty <- ();
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        assertTrue(rules.containsKey("Empty"));

        Parser parser = new Parser(rules, "");
        MatchResult result = parser.parse("Empty");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(0, result.len());
    }

    @Test
    void testEmptyParenthesesInSequence() {
        String grammar = """
            AB <- "a" () "b";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "ab");
        MatchResult result = parser.parse("AB");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(2, result.len());
    }

    @Test
    void testParenthesizedExpressionWithContent() {
        String grammar = """
            Parens <- ("hello");
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "hello");
        MatchResult result = parser.parse("Parens");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(5, result.len());
    }

    @Test
    void testNestedEmptyParentheses() {
        String grammar = """
            Nested <- (());
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "");
        MatchResult result = parser.parse("Nested");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(0, result.len());
    }

    @Test
    void testEmptyParenthesesWithOptionalRepetition() {
        String grammar = """
            Opt <- ()* "test";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "test");
        MatchResult result = parser.parse("Opt");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(4, result.len());
    }

    @Test
    void testEmptyParenthesesInChoice() {
        String grammar = """
            Choice <- "a" / ();
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Should match 'a'
        Parser parser1 = new Parser(rules, "a");
        MatchResult result1 = parser1.parse("Choice");
        assertNotNull(result1);
        assertFalse(result1.isMismatch());
        assertEquals(1, result1.len());

        // Should match empty string
        Parser parser2 = new Parser(rules, "");
        MatchResult result2 = parser2.parse("Choice");
        assertNotNull(result2);
        assertFalse(result2.isMismatch());
        assertEquals(0, result2.len());
    }

    @Test
    void testRuleReferencingNothing() {
        String grammar = """
            Nothing <- ();
            A <- Nothing "a";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "a");
        MatchResult result = parser.parse("A");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());
    }
}
