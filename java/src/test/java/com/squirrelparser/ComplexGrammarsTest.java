package com.squirrelparser;

import com.squirrelparser.*;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class ComplexGrammarsTest {

    @Test
    void arithmeticExpressionGrammar() {
        String grammar = """
            Expr <- Term ("+" Term / "-" Term)*;
            Term <- Factor ("*" Factor / "/" Factor)*;
            Factor <- Number / "(" Expr ")";
            Number <- [0-9]+;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Expr", "42");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(2, result.len());

        parser = new Parser(rules, "Expr", "1+2");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
        assertEquals(3, result.len());

        parser = new Parser(rules, "Expr", "1+2*3");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
        assertEquals(5, result.len());

        parser = new Parser(rules, "Expr", "(1+2)*3");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
        assertEquals(7, result.len());
    }

    @Test
    void identifierAndKeywordGrammar() {
        String grammar = """
            Ident <- !Keyword [a-zA-Z_] [a-zA-Z0-9_]*;
            Keyword <- ("if" / "while" / "for") ![a-zA-Z0-9_];
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Ident", "foo");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        // Use matchRule for negative test to avoid recovery
        parser = new Parser(rules, "Ident", "if");
        MatchResult matchResult = parser.matchRule("Ident", 0);
        assertTrue(matchResult.isMismatch()); // 'if' is a keyword

        parser = new Parser(rules, "Ident", "iffy");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result); // 'iffy' is not a keyword
    }

    @Test
    void jsonGrammar() {
        String grammar = """
            Value <- String / Number / Object / Array / "true" / "false" / "null";
            Object <- "{" _ (Pair (_ "," _ Pair)*)? _ "}";
            Pair <- String _ ":" _ Value;
            Array <- "[" _ (Value (_ "," _ Value)*)? _ "]";
            String <- "\\"" [^"]* "\\"";
            Number <- [0-9]+;
            _ <- [ \\t\\n\\r]*;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Value", "{}");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Value", "[]");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Value", "\"hello\"");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Value", "123");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void whitespaceHandling() {
        String grammar = """
            Main <- _ "hello" _ "world" _;
            _ <- [ \\t\\n\\r]*;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Main", "helloworld");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Main", "  hello   world  ");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Main", "hello\n\tworld");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void commentHandlingWithMetagrammar() {
        String grammar = """
            # This is a comment
            Main <- "test"; # trailing comment
            # Another comment
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        assertTrue(rules.containsKey("Main"));

        Parser parser = new Parser(rules, "Main", "test");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
    }
}
