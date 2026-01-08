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

/**
 * MetaGrammar - Stress Tests
 * Port of stress_test.dart
 */
class StressTest {

    @Test
    void testDeeplyNestedParentheses() {
        // Test parser can handle deeply nested groupings
        String grammar = """
            Rule <- ((((("a")))));
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "a");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());
    }

    @Test
    void testManyChoiceAlternatives() {
        // Stress test with 20 alternatives
        String grammar = """
            Rule <- "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j" /
                    "k" / "l" / "m" / "n" / "o" / "p" / "q" / "r" / "s" / "t" ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Test first alternative
        Parser parser = new Parser(rules, "a");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // Test middle alternative
        parser = new Parser(rules, "j");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // Test last alternative
        parser = new Parser(rules, "t");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testDeeplyNestedChoicesAndSequences() {
        // Complex nesting: (a (b / c) d (e / f / g))
        String grammar = """
            Rule <- "a" ("b" / "c") "d" ("e" / "f" / "g");
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "abde");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "acdg");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "acdf");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testLongSequence() {
        // Test a very long sequence
        String grammar = """
            Rule <- "a" "b" "c" "d" "e" "f" "g" "h" "i" "j"
                    "k" "l" "m" "n" "o" "p" "q" "r" "s" "t";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "abcdefghijklmnopqrst");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(20, result.len());
    }

    @Test
    void testStackedRepetitionOperators() {
        // Test multiple suffix operators: (a+)?
        String grammar = """
            Rule <- ("a"+)?;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Empty input (optional matches)
        Parser parser = new Parser(rules, "");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // One 'a'
        parser = new Parser(rules, "a");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // Multiple 'a's
        parser = new Parser(rules, "aaa");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testComplexLookaheadCombinations() {
        // Test &![0-9] pattern
        String grammar = """
            Rule <- &![0-9] [a-z]+ ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Should match letters not preceded by digits
        Parser parser = new Parser(rules, "hello");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // Should fail on digit start
        parser = new Parser(rules, "5hello");
        Clause rule = rules.get("Rule");
        MatchResult matchResult = parser.probe(rule, 0);
        assertTrue(matchResult.isMismatch());
    }

    @Test
    void testCharacterClassEdgeCases() {
        // Test character classes with many ranges
        String grammar = """
            Rule <- [a-zA-Z0-9_\\\\-\\\\.@]+ ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Test_123-name.email@");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testNegatedCharacterClassWithMultipleRanges() {
        // Everything except digits and whitespace
        String grammar = """
            Rule <- [^0-9 \\t\\n\\r]+ ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "hello");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // Should stop at first digit
        parser = new Parser(rules, "test123");
        Clause rule = rules.get("Rule");
        MatchResult matchResult = parser.probe(rule, 0);
        assertEquals(4, matchResult.len()); // Matches 'test'
    }

    @Test
    void testMultipleTransparentRulesInteracting() {
        String grammar = """
            ~Space <- " " ;
            ~Tab <- "\\t" ;
            ~WS <- (Space / Tab)+ ;
            Main <- WS "hello" WS "world" WS ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "  \thello\t  world \t");
        ASTNode ast = parser.parseToAST("Main");

        assertNotNull(ast);
        // Should have 2 children: "hello" and "world" (WS nodes are transparent)
        assertEquals(2, ast.children.size());
    }

    @Test
    void testDeeplyNestedRuleReferences() {
        String grammar = """
            A <- B ;
            B <- C ;
            C <- D ;
            D <- E ;
            E <- "x" ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "x");
        MatchResult result = parser.parse("A");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testComplexEscapeSequences() {
        // Test escape sequences: newline, tab, quotes
        String grammar = """
            Rule <- "line1\\n\\tquote\\"test" ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "line1\n\tquote\"test");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(17, result.len());
    }

    @Test
    void testCommentsInVariousPositions() {
        String grammar = """
            # Leading comment
            Rule <- # inline comment
                    "a" # after token
                    "b" # another
                    ; # end comment
            # Trailing comment
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "ab");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testMutualRecursionBetweenRules() {
        String grammar = """
            A <- "a" B / "a" ;
            B <- "b" A / "b" ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Just 'a'
        Parser parser = new Parser(rules, "a");
        MatchResult result = parser.parse("A");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // 'aba'
        parser = new Parser(rules, "aba");
        result = parser.parse("A");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // 'ababa'
        parser = new Parser(rules, "ababa");
        result = parser.parse("A");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testComplexLookaheadInRepetition() {
        // Match characters until we see "end"
        String grammar = """
            Rule <- (!"end" .)* "end" ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "hello world end");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(15, result.len()); // "hello world end"
    }

    @Test
    void testOptionalWithLookahead() {
        // Optional digit followed by letter, but only if not followed by digit
        String grammar = """
            Rule <- ([0-9] ![0-9])? [a-z]+ ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Just letters
        Parser parser = new Parser(rules, "hello");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // Digit then letters
        parser = new Parser(rules, "5hello");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testZeroOrMoreWithComplexContent() {
        // Pairs of letters and digits, zero or more times
        String grammar = """
            Rule <- ([a-z] [0-9])* ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Empty
        Parser parser = new Parser(rules, "");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // One pair
        parser = new Parser(rules, "a5");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // Multiple pairs
        parser = new Parser(rules, "a5b3c7");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testChoiceWithLookaheadConditions() {
        // Match different patterns based on lookahead
        String grammar = """
            Rule <- &[a-z] Lowercase / &[A-Z] Uppercase / Digit ;
            Lowercase <- [a-z]+ ;
            Uppercase <- [A-Z]+ ;
            Digit <- [0-9]+ ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "hello");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "WORLD");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "123");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testNestedOptionalAndRepetition() {
        // Optional groups with repetition inside
        String grammar = """
            Rule <- ("a"+ "b"?)* ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "abaab");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "aaabaaaa");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testAnyCharWithRepetitionAndBounds() {
        // Exactly 5 characters
        String grammar = """
            Rule <- . . . . . ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "hello");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(5, result.len());
    }

    @Test
    void testComplexSequenceWithAllOperatorTypes() {
        // Combine all operators in one rule
        String grammar = """
            Rule <- &[a-z] [a-z]+ ![0-9] ("_" [a-z]+)* ([0-9]+)? ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Basic identifier
        Parser parser = new Parser(rules, "hello");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // With underscores
        parser = new Parser(rules, "hello_world_test");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // With trailing digits
        parser = new Parser(rules, "test_var123");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testPathologicalBacktrackingCase() {
        // A pattern that could cause excessive backtracking in naive parsers
        String grammar = """
            Rule <- "a"* "a"* "a"* "a"* "b" ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "aaaaab");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(6, result.len());
    }

    @Test
    void testRuleWithMixedTransparentAndNonTransparentReferences() {
        String grammar = """
            Main <- A ~B C ;
            A <- "a" ;
            ~B <- "b" ;
            C <- "c" ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "abc");
        ASTNode ast = parser.parseToAST("Main");

        assertNotNull(ast);
        assertEquals("Main", ast.label);
        // All three children are present (B appears even though marked transparent)
        assertEquals(3, ast.children.size());
        assertEquals("A", ast.children.get(0).label);
        assertEquals("B", ast.children.get(1).label);
        assertEquals("C", ast.children.get(2).label);
    }

    @Test
    void testCharacterClassWithSpecialCharacters() {
        // Test characters including dot, underscore, hyphen
        String grammar = """
            Rule <- [a-z.@_]+ ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "test.name_value@");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testVeryLongRuleName() {
        String grammar = """
            ThisIsAVeryLongRuleNameToTestThatLongIdentifiersWork <- "test" ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        assertTrue(rules.containsKey("ThisIsAVeryLongRuleNameToTestThatLongIdentifiersWork"));
    }

    @Test
    void testMultipleConsecutiveLookaheads() {
        // Multiple positive lookaheads in sequence
        String grammar = """
            Rule <- &[a-z] &[a-c] "a" ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "a");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // Should fail for 'd' (doesn't match second lookahead)
        parser = new Parser(rules, "d");
        Clause rule = rules.get("Rule");
        MatchResult matchResult = parser.probe(rule, 0);
        assertTrue(matchResult.isMismatch());
    }

    @Test
    void testChoiceWithPotentiallyEmptyMatches() {
        // Test choice where alternatives can match varying lengths
        String grammar = """
            Rule <- "a"+ / "b"+ / "" ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // 'aaa' matches first alternative
        Parser parser = new Parser(rules, "aaa");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // 'bbb' matches second alternative
        parser = new Parser(rules, "bbb");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // Empty input matches third alternative
        parser = new Parser(rules, "");
        Clause rule = rules.get("Rule");
        MatchResult matchResult = parser.probe(rule, 0);
        assertFalse(matchResult.isMismatch());
        assertEquals(0, matchResult.len());
    }

    @Test
    void testNegatedLookaheadWithAlternatives() {
        // Not followed by keyword
        String grammar = """
            Rule <- !(Keyword ![a-z]) [a-z]+ ;
            Keyword <- "if" / "while" / "for" ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Regular identifier works
        Parser parser = new Parser(rules, "hello");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // Keyword prefix works (iffy)
        parser = new Parser(rules, "iffy");
        result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        // Pure keyword should fail
        parser = new Parser(rules, "if");
        Clause rule = rules.get("Rule");
        MatchResult matchResult = parser.probe(rule, 0);
        assertTrue(matchResult.isMismatch());
    }

    @Test
    void testRepetitionOfGroupedAlternation() {
        // Repeat a choice multiple times
        String grammar = """
            Rule <- ("a" / "b" / "c")+ ;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "abccbaabccc");
        MatchResult result = parser.parse("Rule");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(11, result.len());
    }
}
