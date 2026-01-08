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
 * MetaGrammar - Complex Grammars Tests
 * Port of complex_grammars_test.dart
 */
class ComplexGrammarsTest {

    @Test
    void testArithmeticExpressionGrammar() {
        String grammar = """
            Expr <- Term ("+" Term / "-" Term)*;
            Term <- Factor ("*" Factor / "/" Factor)*;
            Factor <- Number / "(" Expr ")";
            Number <- [0-9]+;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "42");
        MatchResult result = parser.parse("Expr");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(2, result.len());

        parser = new Parser(rules, "1+2");
        result = parser.parse("Expr");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(3, result.len());

        parser = new Parser(rules, "1+2*3");
        result = parser.parse("Expr");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(5, result.len());

        parser = new Parser(rules, "(1+2)*3");
        result = parser.parse("Expr");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(7, result.len());
    }

    @Test
    void testIdentifierAndKeywordGrammar() {
        String grammar = """
            Ident <- !Keyword [a-zA-Z_] [a-zA-Z0-9_]*;
            Keyword <- ("if" / "while" / "for") ![a-zA-Z0-9_];
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "foo");
        MatchResult result = parser.parse("Ident");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // Use matchRule for negative test to avoid recovery
        parser = new Parser(rules, "if");
        Clause identRule = rules.get("Ident");
        MatchResult matchResult = parser.probe(identRule, 0);
        assertTrue(matchResult.isMismatch()); // 'if' is a keyword

        parser = new Parser(rules, "iffy");
        result = parser.parse("Ident");
        assertNotNull(result);
        assertFalse(result.isMismatch()); // 'iffy' is not a keyword
    }

    @Test
    void testJSONGrammar() {
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

        Parser parser = new Parser(rules, "{}");
        MatchResult result = parser.parse("Object");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "[]");
        result = parser.parse("Array");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "\"hello\"");
        result = parser.parse("String");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "123");
        result = parser.parse("Number");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testWhitespaceHandling() {
        String grammar = """
            Main <- _ "hello" _ "world" _;
            _ <- [ \\t\\n\\r]*;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "helloworld");
        MatchResult result = parser.parse("Main");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "  hello   world  ");
        result = parser.parse("Main");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "hello\n\tworld");
        result = parser.parse("Main");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testCommentHandlingWithMetagrammar() {
        String grammar = """
            # This is a comment
            Main <- "test"; # trailing comment
            # Another comment
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        assertTrue(rules.containsKey("Main"));

        Parser parser = new Parser(rules, "test");
        MatchResult result = parser.parse("Main");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }
}
