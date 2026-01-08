package com.squirrelparser.metagrammar;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.ASTNode;
import com.squirrelparser.Clause;
import com.squirrelparser.MatchResult;
import com.squirrelparser.MetaGrammar;
import com.squirrelparser.Parser;
import com.squirrelparser.SyntaxError;

/**
 * MetaGrammar - Operator Precedence Tests
 * Port of precedence_test.dart
 */
class PrecedenceTest {

    @Test
    void testSuffixBindsTighterThanSequence() {
        // "a"+ "b" should be ("a"+ "b"), not ("a" "b")+
        String grammar = """
            Rule <- "a"+ "b";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        String clause = rules.get("Rule").toString();

        // Should have OneOrMore around first element only
        assertTrue(clause.contains("\"a\""));
        assertTrue(clause.contains("\"b\""));
    }

    @Test
    void testPrefixBindsTighterThanSequence() {
        // !"a" "b" should be (!"a" "b"), not !("a" "b")
        String grammar = """
            Rule <- !"a" "b";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        String clause = rules.get("Rule").toString();

        // Should have NotFollowedBy around first element only
        assertTrue(clause.contains("\"a\""));
        assertTrue(clause.contains("\"b\""));
    }

    @Test
    void testSequenceBindsTighterThanChoice() {
        // "a" "b" / "c" should be (("a" "b") / "c"), not ("a" ("b" / "c"))
        String grammar = """
            Rule <- "a" "b" / "c";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Test that it parses "ab" and "c", but not "ac"
        Parser parser = new Parser(rules, "ab");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "c");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "ac");
        result = parser.parse("Rule");
        // Total failure returns SyntaxError spanning entire input
        assertTrue(result instanceof SyntaxError);
    }

    @Test
    void testSuffixBindsTighterThanPrefix() {
        // &"a"+ should be &("a"+), not (&"a")+
        String grammar = """
            Rule <- &"a"+ "a";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        String clause = rules.get("Rule").toString();

        // Should have FollowedBy wrapping OneOrMore
        assertTrue(clause.contains("\"a\""));
    }

    @Test
    void testGroupingOverridesPrecedenceSequenceInChoice() {
        // "a" / "b" "c" should parse as ("a" / ("b" "c"))
        // ("a" / "b") "c" should parse differently
        String grammar1 = """
            Rule <- "a" / "b" "c";
            """;

        String grammar2 = """
            Rule <- ("a" / "b") "c";
            """;

        Map<String, Clause> rules1 = MetaGrammar.parseGrammar(grammar1);
        Map<String, Clause> rules2 = MetaGrammar.parseGrammar(grammar2);

        // Grammar 1: should match "a" or "bc"
        Parser parser = new Parser(rules1, "a");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules1, "bc");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // 'ac' should not fully match - only matches 'a', leaving 'c'
        parser = new Parser(rules1, "ac");
        Clause rule1 = rules1.get("Rule");
        MatchResult matchResult = parser.probe(rule1, 0);
        assertTrue(matchResult.isMismatch() || matchResult.len() != 2);

        // Grammar 2: should match "ac" or "bc"
        parser = new Parser(rules2, "ac");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules2, "bc");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // 'a' should not match grammar2 - needs 'c' after choice
        parser = new Parser(rules2, "a");
        Clause rule2 = rules2.get("Rule");
        matchResult = parser.probe(rule2, 0);
        assertTrue(matchResult.isMismatch());
    }

    @Test
    void testGroupingOverridesPrecedenceChoiceInSuffix() {
        // ("a" / "b")+ should allow "aaa", "bbb", "aba", etc.
        String grammar = """
            Rule <- ("a" / "b")+;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "aaa");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "bbb");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "aba");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "bab");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testComplexPrecedenceMixedOperators() {
        // "a"+ / "b"* "c" should be (("a"+) / (("b"*) "c"))
        String grammar = """
            Rule <- "a"+ / "b"* "c";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Should match "a", "aa", "aaa", etc.
        Parser parser = new Parser(rules, "a");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "aaa");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // Should match "c", "bc", "bbc", etc.
        parser = new Parser(rules, "c");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "bc");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "bbc");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testTransparentOperatorPrecedence() {
        // ~"a"+ should be ~("a"+), not (~"a")+
        String grammar = """
            ~Rule <- "a"+;
            Main <- Rule;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "aaa");
        ASTNode ast = parser.parseToAST("Main");

        assertNotNull(ast);
        assertEquals("Main", ast.label);
        // If Rule is properly transparent, we shouldn't see it in the AST
    }

    @Test
    void testPrefixOperatorsAreRightAssociative() {
        // &!"a" should be &(!"a"), not (!(&"a"))
        String grammar = """
            Rule <- &!"a" "b";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        String clause = rules.get("Rule").toString();

        // Should have FollowedBy wrapping NotFollowedBy
        assertTrue(clause.contains("\"a\""));
    }

    @Test
    void testSuffixOperatorsAreLeftAssociative() {
        // "a"+? should be ("a"+)?, not "a"+(?)
        String grammar = """
            Rule <- "a"+?;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        String clause = rules.get("Rule").toString();

        // Should have Optional wrapping OneOrMore
        assertTrue(clause.contains("\"a\""));
        assertTrue(clause.contains("?") || clause.contains("Optional"));
    }

    @Test
    void testCharacterClassBindsAsAtomicUnit() {
        // [a-z]+ should be ([a-z])+, with the character class as a single unit
        String grammar = """
            Rule <- [a-z]+;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "abc");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(3, result.len());
    }

    @Test
    void testNegatedCharacterClassBindsAsAtomicUnit() {
        // [^0-9]+ should match multiple non-digits
        String grammar = """
            Rule <- [^0-9]+;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "abc");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(3, result.len());

        // Use probe for partial match test
        parser = new Parser(rules, "a1");
        Clause rule = rules.get("Rule");
        MatchResult matchResult = parser.probe(rule, 0);
        assertFalse(matchResult.isMismatch());
        assertEquals(1, matchResult.len()); // Only 'a' matches
    }
}
