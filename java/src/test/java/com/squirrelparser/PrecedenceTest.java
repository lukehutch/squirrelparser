package com.squirrelparser;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

class PrecedenceTest {

    @Test
    void suffixBindsTighterThanSequence() {
        // "a"+ "b" should be ("a"+ "b"), not ("a" "b")+
        String grammar = """
            Rule <- "a"+ "b";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        String clause = rules.get("Rule").toString();

        // Should have OneOrMore around first element only
        assertTrue(clause.contains("\"a\"+"));
        assertTrue(clause.contains("\"b\""));
    }

    @Test
    void prefixBindsTighterThanSequence() {
        // !"a" "b" should be (!"a" "b"), not !("a" "b")
        String grammar = """
            Rule <- !"a" "b";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        String clause = rules.get("Rule").toString();

        // Should have NotFollowedBy around first element only
        assertTrue(clause.contains("!\"a\""));
        assertTrue(clause.contains("\"b\""));
    }

    @Test
    void sequenceBindsTighterThanChoice() {
        // "a" "b" / "c" should be (("a" "b") / "c"), not ("a" ("b" / "c"))
        String grammar = """
            Rule <- "a" "b" / "c";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Test that it parses "ab" and "c", but not "ac"
        Parser parser = new Parser(rules, "Rule", "ab");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Rule", "c");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Rule", "ac");
        parseResult = parser.parse();
        result = parseResult.root();
        assertTrue(result instanceof SyntaxError);
    }

    @Test
    void suffixBindsTighterThanPrefix() {
        // &"a"+ should be &("a"+), not (&"a")+
        String grammar = """
            Rule <- &"a"+ "a";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        String clause = rules.get("Rule").toString();

        // Should have FollowedBy wrapping OneOrMore
        assertTrue(clause.contains("&\"a\"+"));
    }

    @Test
    void groupingOverridesPrecedenceSequenceInChoice() {
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
        Parser parser = new Parser(rules1, "Rule", "a");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules1, "Rule", "bc");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        // 'ac' should not fully match - only matches 'a', leaving 'c'
        parser = new Parser(rules1, "Rule", "ac");
        MatchResult matchResult = parser.matchRule("Rule", 0);
        assertTrue(matchResult.isMismatch() || matchResult.len() != 2); // Either mismatch or doesn't consume all

        // Grammar 2: should match "ac" or "bc"
        parser = new Parser(rules2, "Rule", "ac");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules2, "Rule", "bc");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        // 'a' should not match grammar2 - needs 'c' after choice
        parser = new Parser(rules2, "Rule", "a");
        matchResult = parser.matchRule("Rule", 0);
        assertTrue(matchResult.isMismatch());
    }

    @Test
    void groupingOverridesPrecedenceChoiceInSuffix() {
        // ("a" / "b")+ should allow "aaa", "bbb", "aba", etc.
        String grammar = """
            Rule <- ("a" / "b")+;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Rule", "aaa");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Rule", "bbb");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Rule", "aba");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Rule", "bab");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void complexPrecedenceMixedOperators() {
        // "a"+ / "b"* "c" should be (("a"+) / (("b"*) "c"))
        String grammar = """
            Rule <- "a"+ / "b"* "c";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Should match "a", "aa", "aaa", etc.
        Parser parser = new Parser(rules, "Rule", "a");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Rule", "aaa");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        // Should match "c", "bc", "bbc", etc.
        parser = new Parser(rules, "Rule", "c");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Rule", "bc");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Rule", "bbc");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void transparentOperatorPrecedence() {
        // ~"a"+ should be ~("a"+), not (~"a")+
        String grammar = """
            ~Rule <- "a"+;
            Main <- Rule;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Main", "aaa");
        ParseResult parseResult = parser.parse();

        // Rule should be transparent, so it should be successfully parsed
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(3, result.len()); // Should match the full input 'aaa'
    }

    @Test
    void prefixOperatorsAreRightAssociative() {
        // &!"a" should be &(!"a"), not (!(&"a"))
        String grammar = """
            Rule <- &!"a" "b";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        String clause = rules.get("Rule").toString();

        // Should have FollowedBy wrapping NotFollowedBy
        assertTrue(clause.contains("&!\"a\""));
    }

    @Test
    void suffixOperatorsAreLeftAssociative() {
        // "a"+? should be ("a"+)?, not "a"+(?)
        // This test verifies that suffix operators apply to the result of the previous operation
        String grammar = """
            Rule <- "a"+?;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        String clause = rules.get("Rule").toString();

        // Should have Optional wrapping OneOrMore
        assertTrue(clause.contains("\"a\"+"));
        assertTrue(clause.contains("?"));
    }

    @Test
    void characterClassBindsAsAtomicUnit() {
        // [a-z]+ should be ([a-z])+, with the character class as a single unit
        String grammar = """
            Rule <- [a-z]+;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Rule", "abc");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(3, result.len());
    }

    @Test
    void negatedCharacterClassBindsAsAtomicUnit() {
        // [^0-9]+ should match multiple non-digits
        String grammar = """
            Rule <- [^0-9]+;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Rule", "abc");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(3, result.len());

        // Use matchRule for partial match test
        parser = new Parser(rules, "Rule", "a1");
        MatchResult matchResult = parser.matchRule("Rule", 0);
        assertFalse(matchResult.isMismatch());
        assertEquals(1, matchResult.len()); // Only 'a' matches
    }
}
