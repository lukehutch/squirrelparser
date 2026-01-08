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
import com.squirrelparser.SyntaxError; // Now public, can be imported

/**
 * MetaGrammar - Character Classes Tests
 * Port of character_class_test.dart
 */
class CharacterClassTest {

    @Test
    void testSimpleCharacterRange() {
        String grammar = """
            Digit <- [0-9];
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "5");
        MatchResult result = parser.parse("Digit");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());

        parser = new Parser(rules, "a");
        result = parser.parse("Digit");
        // Total failure returns SyntaxError spanning entire input
        assertTrue(result instanceof SyntaxError);
    }

    @Test
    void testMultipleCharacterRanges() {
        String grammar = """
            AlphaNum <- [a-zA-Z0-9];
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "a");
        MatchResult result = parser.parse("AlphaNum");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "Z");
        result = parser.parse("AlphaNum");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "5");
        result = parser.parse("AlphaNum");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "!");
        result = parser.parse("AlphaNum");
        // Total failure returns SyntaxError spanning entire input
        assertTrue(result instanceof SyntaxError);
    }

    @Test
    void testCharacterClassWithIndividualCharacters() {
        String grammar = """
            Vowel <- [aeiou];
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "a");
        MatchResult result = parser.parse("Vowel");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "e");
        result = parser.parse("Vowel");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "b");
        result = parser.parse("Vowel");
        // Total failure returns SyntaxError spanning entire input
        assertTrue(result instanceof SyntaxError);
    }

    @Test
    void testNegatedCharacterClass() {
        String grammar = """
            NotDigit <- [^0-9];
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "a");
        MatchResult result = parser.parse("NotDigit");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "5");
        result = parser.parse("NotDigit");
        // Total failure returns SyntaxError spanning entire input
        assertTrue(result instanceof SyntaxError);
    }

    @Test
    void testEscapedCharactersInCharacterClass() {
        String grammar = """
            Special <- [\\t\\n];
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "\t");
        MatchResult result = parser.parse("Special");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "\n");
        result = parser.parse("Special");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, " ");
        result = parser.parse("Special");
        // Total failure returns SyntaxError spanning entire input
        assertTrue(result instanceof SyntaxError);
    }
}
