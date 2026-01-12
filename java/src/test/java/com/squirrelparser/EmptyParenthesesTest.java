package com.squirrelparser;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

class EmptyParenthesesTest {

    @Test
    void emptyParenthesesMatchesEmptyString() {
        String grammar = """
            Empty <- ();
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        assertTrue(rules.containsKey("Empty"));

        Parser parser = new Parser(rules, "Empty", "");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(0, result.len());
    }

    @Test
    void emptyParenthesesInSequence() {
        String grammar = """
            AB <- "a" () "b";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "AB", "ab");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(2, result.len());
    }

    @Test
    void parenthesizedExpressionWithContent() {
        String grammar = """
            Parens <- ("hello");
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Parens", "hello");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(5, result.len());
    }

    @Test
    void nestedEmptyParentheses() {
        String grammar = """
            Nested <- (());
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Nested", "");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(0, result.len());
    }

    @Test
    void emptyParenthesesWithOptionalRepetition() {
        String grammar = """
            Opt <- ()* "test";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Opt", "test");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(4, result.len());
    }

    @Test
    void emptyParenthesesInChoice() {
        String grammar = """
            Choice <- "a" / ();
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Should match 'a'
        Parser parser1 = new Parser(rules, "Choice", "a");
        ParseResult parseResult1 = parser1.parse();
        MatchResult result1 = parseResult1.root();
        assertNotNull(result1);
        assertEquals(1, result1.len());

        // Should match empty string
        Parser parser2 = new Parser(rules, "Choice", "");
        ParseResult parseResult2 = parser2.parse();
        MatchResult result2 = parseResult2.root();
        assertNotNull(result2);
        assertEquals(0, result2.len());
    }

    @Test
    void ruleReferencingNothing() {
        String grammar = """
            Nothing <- ();
            A <- Nothing "a";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "A", "a");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(1, result.len());
    }
}
