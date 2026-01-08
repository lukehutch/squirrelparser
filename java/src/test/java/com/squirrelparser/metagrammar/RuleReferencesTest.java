package com.squirrelparser.metagrammar;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Clause;
import com.squirrelparser.MatchResult;
import com.squirrelparser.MetaGrammar;
import com.squirrelparser.Parser;

/**
 * MetaGrammar - Rule References Tests
 * Port of rule_references_test.dart
 */
class RuleReferencesTest {

    @Test
    void testSimpleRuleReference() {
        String grammar = """
            Main <- A "b";
            A <- "a";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "ab");
        MatchResult result = parser.parse("Main");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(2, result.len());
    }

    @Test
    void testMultipleRuleReferences() {
        String grammar = """
            Main <- A B C;
            A <- "a";
            B <- "b";
            C <- "c";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "abc");
        MatchResult result = parser.parse("Main");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(3, result.len());
    }

    @Test
    void testRecursiveRule() {
        String grammar = """
            List <- "a" List / "a";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "a");
        MatchResult result = parser.parse("List");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());

        parser = new Parser(rules, "aaa");
        result = parser.parse("List");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(3, result.len());
    }

    @Test
    void testMutuallyRecursiveRules() {
        String grammar = """
            A <- "a" B / "a";
            B <- "b" A / "b";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "aba");
        MatchResult result = parser.parse("A");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(3, result.len());

        parser = new Parser(rules, "bab");
        result = parser.parse("B");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(3, result.len());
    }

    @Test
    void testLeftRecursiveRule() {
        String grammar = """
            Expr <- Expr "+" "n" / "n";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "n");
        MatchResult result = parser.parse("Expr");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());

        parser = new Parser(rules, "n+n");
        result = parser.parse("Expr");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(3, result.len());

        parser = new Parser(rules, "n+n+n");
        result = parser.parse("Expr");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(5, result.len());
    }
}
