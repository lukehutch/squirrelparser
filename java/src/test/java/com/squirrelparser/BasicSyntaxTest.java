package com.squirrelparser;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

class BasicSyntaxTest {

    @Test
    void simpleRuleWithStringLiteral() {
        String grammar = """
            Hello <- "hello";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        assertTrue(rules.containsKey("Hello"));

        Parser parser = new Parser(rules, "Hello", "hello");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(5, result.len());
    }

    @Test
    void ruleWithCharacterLiteral() {
        String grammar = """
            A <- 'a';
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "A", "a");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(1, result.len());
    }

    @Test
    void sequenceOfLiterals() {
        String grammar = """
            AB <- "a" "b";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "AB", "ab");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(2, result.len());
    }

    @Test
    void choiceBetweenAlternatives() {
        String grammar = """
            AorB <- "a" / "b";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "AorB", "a");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(1, result.len());

        parser = new Parser(rules, "AorB", "b");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
        assertEquals(1, result.len());
    }

    @Test
    void zeroOrMoreRepetition() {
        String grammar = """
            As <- "a"*;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "As", "");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(0, result.len());

        parser = new Parser(rules, "As", "aaa");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
        assertEquals(3, result.len());
    }

    @Test
    void oneOrMoreRepetition() {
        String grammar = """
            As <- "a"+;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "As", "");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertTrue(result instanceof SyntaxError);

        parser = new Parser(rules, "As", "aaa");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
        assertEquals(3, result.len());
    }

    @Test
    void optional() {
        String grammar = """
            OptA <- "a"?;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "OptA", "");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(0, result.len());

        parser = new Parser(rules, "OptA", "a");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
        assertEquals(1, result.len());
    }

    @Test
    void positiveLookahead() {
        String grammar = """
            AFollowedByB <- "a" &"b" "b";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "AFollowedByB", "ab");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(2, result.len()); // Both 'a' and 'b' consumed

        parser = new Parser(rules, "AFollowedByB", "ac");
        parseResult = parser.parse();
        result = parseResult.root();
        assertTrue(result instanceof SyntaxError);
    }

    @Test
    void negativeLookahead() {
        String grammar = """
            ANotFollowedByB <- "a" !"b" "c";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "ANotFollowedByB", "ac");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(2, result.len()); // Both 'a' and 'c' consumed

        parser = new Parser(rules, "ANotFollowedByB", "ab");
        parseResult = parser.parse();
        result = parseResult.root();
        assertTrue(result instanceof SyntaxError);
    }

    @Test
    void anyCharacter() {
        String grammar = """
            AnyOne <- .;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "AnyOne", "x");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(1, result.len());

        parser = new Parser(rules, "AnyOne", "9");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
        assertEquals(1, result.len());
    }

    @Test
    void groupingWithParentheses() {
        String grammar = """
            Group <- ("a" / "b") "c";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Group", "ac");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(2, result.len());

        parser = new Parser(rules, "Group", "bc");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
        assertEquals(2, result.len());
    }
}
