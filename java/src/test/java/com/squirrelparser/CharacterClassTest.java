package com.squirrelparser;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.clause.terminal.CharSet;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.MetaGrammar;
import com.squirrelparser.parser.ParseResult;
import com.squirrelparser.parser.Parser;
import com.squirrelparser.parser.SyntaxError;

class CharacterClassTest {

    @Nested
    class CharSetTerminalDirectConstruction {

        @Test
        void charSetRangeMatchesCharactersInRange() {
            CharSet charSet = CharSet.range("a", "z");
            Map<String, Clause> rules = Map.of("S", charSet);

            Parser parser = new Parser(rules, "S", "a");
            assertFalse(parser.parse().root() instanceof SyntaxError, "should match a");

            parser = new Parser(rules, "S", "m");
            assertFalse(parser.parse().root() instanceof SyntaxError, "should match m");

            parser = new Parser(rules, "S", "z");
            assertFalse(parser.parse().root() instanceof SyntaxError, "should match z");

            parser = new Parser(rules, "S", "A");
            assertTrue(parser.parse().root() instanceof SyntaxError, "should not match A");
        }

        @Test
        void charSetCharMatchesSingleCharacter() {
            CharSet charSet = CharSet.ofChar("x");
            Map<String, Clause> rules = Map.of("S", charSet);

            Parser parser = new Parser(rules, "S", "x");
            assertFalse(parser.parse().root() instanceof SyntaxError, "should match x");

            parser = new Parser(rules, "S", "y");
            assertTrue(parser.parse().root() instanceof SyntaxError, "should not match y");
        }

        @Test
        void charSetWithMultipleRanges() {
            // [a-zA-Z0-9]
            CharSet charSet = new CharSet(List.of(
                new int[]{"a".codePointAt(0), "z".codePointAt(0)},
                new int[]{"A".codePointAt(0), "Z".codePointAt(0)},
                new int[]{"0".codePointAt(0), "9".codePointAt(0)}
            ));
            Map<String, Clause> rules = Map.of("S", charSet);

            // Test lowercase
            Parser parser = new Parser(rules, "S", "a");
            assertFalse(parser.parse().root() instanceof SyntaxError);
            parser = new Parser(rules, "S", "z");
            assertFalse(parser.parse().root() instanceof SyntaxError);

            // Test uppercase
            parser = new Parser(rules, "S", "A");
            assertFalse(parser.parse().root() instanceof SyntaxError);
            parser = new Parser(rules, "S", "Z");
            assertFalse(parser.parse().root() instanceof SyntaxError);

            // Test digits
            parser = new Parser(rules, "S", "0");
            assertFalse(parser.parse().root() instanceof SyntaxError);
            parser = new Parser(rules, "S", "9");
            assertFalse(parser.parse().root() instanceof SyntaxError);

            // Test non-alphanumeric
            parser = new Parser(rules, "S", "!");
            assertTrue(parser.parse().root() instanceof SyntaxError);
            parser = new Parser(rules, "S", " ");
            assertTrue(parser.parse().root() instanceof SyntaxError);
        }

        @Test
        void charSetWithInversion() {
            // [^a-z] - matches anything NOT a lowercase letter
            CharSet charSet = new CharSet(List.of(
                new int[]{"a".codePointAt(0), "z".codePointAt(0)}
            ), true);
            Map<String, Clause> rules = Map.of("S", charSet);

            // Should NOT match lowercase
            Parser parser = new Parser(rules, "S", "a");
            assertTrue(parser.parse().root() instanceof SyntaxError, "should not match a");
            parser = new Parser(rules, "S", "m");
            assertTrue(parser.parse().root() instanceof SyntaxError, "should not match m");
            parser = new Parser(rules, "S", "z");
            assertTrue(parser.parse().root() instanceof SyntaxError, "should not match z");

            // Should match uppercase, digits, symbols
            parser = new Parser(rules, "S", "A");
            assertFalse(parser.parse().root() instanceof SyntaxError, "should match A");
            parser = new Parser(rules, "S", "5");
            assertFalse(parser.parse().root() instanceof SyntaxError, "should match 5");
            parser = new Parser(rules, "S", "!");
            assertFalse(parser.parse().root() instanceof SyntaxError, "should match !");
        }

        @Test
        void charSetWithInvertedMultipleRanges() {
            // [^a-zA-Z] - matches anything NOT a letter
            CharSet charSet = new CharSet(List.of(
                new int[]{"a".codePointAt(0), "z".codePointAt(0)},
                new int[]{"A".codePointAt(0), "Z".codePointAt(0)}
            ), true);
            Map<String, Clause> rules = Map.of("S", charSet);

            // Should NOT match letters
            Parser parser = new Parser(rules, "S", "a");
            assertTrue(parser.parse().root() instanceof SyntaxError, "should not match a");
            parser = new Parser(rules, "S", "Z");
            assertTrue(parser.parse().root() instanceof SyntaxError, "should not match Z");

            // Should match digits and symbols
            parser = new Parser(rules, "S", "5");
            assertFalse(parser.parse().root() instanceof SyntaxError, "should match 5");
            parser = new Parser(rules, "S", "!");
            assertFalse(parser.parse().root() instanceof SyntaxError, "should match !");
        }

        @Test
        void charSetNotRangeConvenienceConstructor() {
            CharSet charSet = CharSet.notRange("0", "9");
            Map<String, Clause> rules = Map.of("S", charSet);

            // Should NOT match digits
            Parser parser = new Parser(rules, "S", "5");
            assertTrue(parser.parse().root() instanceof SyntaxError, "should not match 5");

            // Should match non-digits
            parser = new Parser(rules, "S", "a");
            assertFalse(parser.parse().root() instanceof SyntaxError, "should match a");
        }

        @Test
        void charSetToStringFormatsCorrectly() {
            assertEquals("[a-z]", CharSet.range("a", "z").toString());
            assertEquals("[x]", CharSet.ofChar("x").toString());
            assertEquals("[a-z0-9]", new CharSet(List.of(
                new int[]{"a".codePointAt(0), "z".codePointAt(0)},
                new int[]{"0".codePointAt(0), "9".codePointAt(0)}
            )).toString());
            assertEquals("[^a-z]", new CharSet(List.of(
                new int[]{"a".codePointAt(0), "z".codePointAt(0)}
            ), true).toString());
        }

        @Test
        void charSetHandlesEmptyInput() {
            CharSet charSet = CharSet.range("a", "z");
            Map<String, Clause> rules = Map.of("S", charSet);

            Parser parser = new Parser(rules, "S", "");
            assertTrue(parser.parse().root() instanceof SyntaxError, "should not match empty");
        }
    }

    @Nested
    class MetaGrammarCharacterClasses {

        @Test
        void simpleCharacterRange() {
            String grammar = """
                Digit <- [0-9];
            """;

            Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

            Parser parser = new Parser(rules, "Digit", "5");
            ParseResult parseResult = parser.parse();
            MatchResult result = parseResult.root();
            assertFalse(result instanceof SyntaxError, "should match digit");
            assertEquals(1, result.len());

            parser = new Parser(rules, "Digit", "a");
            parseResult = parser.parse();
            result = parseResult.root();
            assertTrue(result instanceof SyntaxError, "should fail on non-digit");
        }

        @Test
        void multipleCharacterRanges() {
            String grammar = """
                AlphaNum <- [a-zA-Z0-9];
            """;

            Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

            Parser parser = new Parser(rules, "AlphaNum", "a");
            ParseResult parseResult = parser.parse();
            MatchResult result = parseResult.root();
            assertFalse(result instanceof SyntaxError);

            parser = new Parser(rules, "AlphaNum", "Z");
            parseResult = parser.parse();
            result = parseResult.root();
            assertFalse(result instanceof SyntaxError);

            parser = new Parser(rules, "AlphaNum", "5");
            parseResult = parser.parse();
            result = parseResult.root();
            assertFalse(result instanceof SyntaxError);

            parser = new Parser(rules, "AlphaNum", "!");
            parseResult = parser.parse();
            result = parseResult.root();
            assertTrue(result instanceof SyntaxError, "should fail on non-alphanumeric");
        }

        @Test
        void characterClassWithIndividualCharacters() {
            String grammar = """
                Vowel <- [aeiou];
            """;

            Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

            Parser parser = new Parser(rules, "Vowel", "a");
            ParseResult parseResult = parser.parse();
            MatchResult result = parseResult.root();
            assertFalse(result instanceof SyntaxError);

            parser = new Parser(rules, "Vowel", "e");
            parseResult = parser.parse();
            result = parseResult.root();
            assertFalse(result instanceof SyntaxError);

            parser = new Parser(rules, "Vowel", "b");
            parseResult = parser.parse();
            result = parseResult.root();
            assertTrue(result instanceof SyntaxError, "should fail on consonant");
        }

        @Test
        void negatedCharacterClass() {
            String grammar = """
                NotDigit <- [^0-9];
            """;

            Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

            Parser parser = new Parser(rules, "NotDigit", "a");
            ParseResult parseResult = parser.parse();
            MatchResult result = parseResult.root();
            assertFalse(result instanceof SyntaxError);

            parser = new Parser(rules, "NotDigit", "5");
            parseResult = parser.parse();
            result = parseResult.root();
            assertTrue(result instanceof SyntaxError, "should fail on digit");
        }

        @Test
        void escapedCharactersInCharacterClass() {
            String grammar = """
                Special <- [\\t\\n];
            """;

            Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

            Parser parser = new Parser(rules, "Special", "\t");
            ParseResult parseResult = parser.parse();
            MatchResult result = parseResult.root();
            assertFalse(result instanceof SyntaxError);

            parser = new Parser(rules, "Special", "\n");
            parseResult = parser.parse();
            result = parseResult.root();
            assertFalse(result instanceof SyntaxError);

            parser = new Parser(rules, "Special", " ");
            parseResult = parser.parse();
            result = parseResult.root();
            assertTrue(result instanceof SyntaxError, "should fail on space");
        }
    }
}
