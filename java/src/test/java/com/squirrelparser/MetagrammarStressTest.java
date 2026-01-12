package com.squirrelparser;

import com.squirrelparser.*;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class MetagrammarStressTest {

    @Test
    void deeplyNestedParentheses() {
        // Test parser can handle deeply nested groupings
        String grammar = """
            Rule <- ((((("a")))));
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Rule", "a");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(1, result.len());
    }

    @Test
    void manyChoiceAlternatives() {
        // Stress test with 20 alternatives
        String grammar = """
            Rule <- "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j" /
                    "k" / "l" / "m" / "n" / "o" / "p" / "q" / "r" / "s" / "t" ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Test first alternative
        Parser parser = new Parser(rules, "Rule", "a");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        // Test middle alternative
        parser = new Parser(rules, "Rule", "j");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        // Test last alternative
        parser = new Parser(rules, "Rule", "t");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void deeplyNestedChoicesAndSequences() {
        // Complex nesting: (a (b / c) d (e / f / g))
        String grammar = """
            Rule <- "a" ("b" / "c") "d" ("e" / "f" / "g");
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Rule", "abde");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Rule", "acdg");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Rule", "acdf");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void longSequence() {
        // Test a very long sequence
        String grammar = """
            Rule <- "a" "b" "c" "d" "e" "f" "g" "h" "i" "j"
                    "k" "l" "m" "n" "o" "p" "q" "r" "s" "t";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Rule", "abcdefghijklmnopqrst");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(20, result.len());
    }

    @Test
    void stackedRepetitionOperators() {
        // Test multiple suffix operators: (a+)?*
        // This is a bit pathological but should parse
        String grammar = """
            Rule <- ("a"+)?;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Empty input (optional matches)
        Parser parser = new Parser(rules, "Rule", "");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        // One 'a'
        parser = new Parser(rules, "Rule", "a");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        // Multiple 'a's
        parser = new Parser(rules, "Rule", "aaa");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void complexLookaheadCombinations() {
        // Test &!&! pattern
        String grammar = """
            Rule <- &![0-9] [a-z]+ ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Should match letters not preceded by digits
        Parser parser = new Parser(rules, "Rule", "hello");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        // Should fail on digit start
        parser = new Parser(rules, "Rule", "5hello");
        MatchResult matchResult = parser.matchRule("Rule", 0);
        assertTrue(matchResult.isMismatch());
    }

    @Test
    void characterClassEdgeCases() {
        // Test character classes with many ranges
        String grammar = """
            Rule <- [a-zA-Z0-9_-.@]+ ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Rule", "Test_123-name.email@");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void negatedCharacterClassWithMultipleRanges() {
        // Everything except digits and whitespace
        String grammar = """
            Rule <- [^0-9 \\t\\n\\r]+ ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Rule", "hello");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        // Should stop at first digit
        parser = new Parser(rules, "Rule", "test123");
        MatchResult matchResult = parser.matchRule("Rule", 0);
        assertEquals(4, matchResult.len()); // Matches 'test'
    }

    @Test
    void multipleTransparentRulesInteracting() {
        String grammar = """
            ~Space <- " " ;
            ~Tab <- "\\t" ;
            ~WS <- (Space / Tab)+ ;
            Main <- WS "hello" WS "world" WS ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Main", "  \thello\t  world \t");
        ParseResult parseResult = parser.parse();
        ASTNode ast = ASTBuilder.buildAST(parseResult);

        assertNotNull(ast);
        // Should have 2 children: "hello" and "world" (WS nodes are transparent)
        assertEquals(2, ast.children().size());
    }

    @Test
    void deeplyNestedRuleReferences() {
        String grammar = """
            A <- B ;
            B <- C ;
            C <- D ;
            D <- E ;
            E <- "x" ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "A", "x");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void complexEscapeSequences() {
        // Test escape sequences: newline, tab, quotes
        String grammar = """
            Rule <- "line1\\n\\tquote\\"test" ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Rule", "line1\n\tquote\"test");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(17, result.len());
    }

    @Test
    void commentsInVariousPositions() {
        String grammar = """
            # Leading comment
            Rule <- # inline comment
                    "a" # after token
                    "b" # another
                    ; # end comment
            # Trailing comment
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Rule", "ab");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void mutualRecursionBetweenRules() {
        String grammar = """
            A <- "a" B / "a" ;
            B <- "b" A / "b" ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Just 'a'
        Parser parser = new Parser(rules, "A", "a");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        // 'aba'
        parser = new Parser(rules, "A", "aba");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        // 'ababa'
        parser = new Parser(rules, "A", "ababa");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void complexLookaheadInRepetition() {
        // Match characters until we see "end"
        String grammar = """
            Rule <- (!"end" .)* "end" ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Rule", "hello world end");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(15, result.len()); // "hello world end"
    }

    @Test
    void optionalWithLookahead() {
        // Optional digit followed by letter, but only if not followed by digit
        String grammar = """
            Rule <- ([0-9] ![0-9])? [a-z]+ ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Just letters
        Parser parser = new Parser(rules, "Rule", "hello");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        // Digit then letters
        parser = new Parser(rules, "Rule", "5hello");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void zeroOrMoreWithComplexContent() {
        // Pairs of letters and digits, zero or more times
        String grammar = """
            Rule <- ([a-z] [0-9])* ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Empty
        Parser parser = new Parser(rules, "Rule", "");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        // One pair
        parser = new Parser(rules, "Rule", "a5");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        // Multiple pairs
        parser = new Parser(rules, "Rule", "a5b3c7");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void choiceWithLookaheadConditions() {
        // Match different patterns based on lookahead
        String grammar = """
            Rule <- &[a-z] Lowercase / &[A-Z] Uppercase / Digit ;
            Lowercase <- [a-z]+ ;
            Uppercase <- [A-Z]+ ;
            Digit <- [0-9]+ ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Rule", "hello");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Rule", "WORLD");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Rule", "123");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void nestedOptionalAndRepetition() {
        // Optional groups with repetition inside
        String grammar = """
            Rule <- ("a"+ "b"?)* ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Rule", "");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Rule", "abaab");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "Rule", "aaabaaaa");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void anyCharWithRepetitionAndBounds() {
        // Exactly 5 characters
        String grammar = """
            Rule <- . . . . . ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Rule", "hello");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(5, result.len());
    }

    @Test
    void complexSequenceWithAllOperatorTypes() {
        // Combine all operators in one rule
        String grammar = """
            Rule <- &[a-z] [a-z]+ ![0-9] ("_" [a-z]+)* ([0-9]+)? ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Basic identifier
        Parser parser = new Parser(rules, "Rule", "hello");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        // With underscores
        parser = new Parser(rules, "Rule", "hello_world_test");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        // With trailing digits
        parser = new Parser(rules, "Rule", "test_var123");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void pathologicalBacktrackingCase() {
        // A pattern that could cause excessive backtracking in naive parsers
        String grammar = """
            Rule <- "a"* "a"* "a"* "a"* "b" ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Rule", "aaaaab");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(6, result.len());
    }

    @Test
    void ruleWithMixedTransparentAndNonTransparentReferences() {
        String grammar = """
            Main <- A ~B C ;
            A <- "a" ;
            ~B <- "b" ;
            C <- "c" ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Main", "abc");
        ParseResult parseResult = parser.parse();
        ASTNode ast = ASTBuilder.buildAST(parseResult);

        assertNotNull(ast);
        assertEquals("Main", ast.label());
        // Transparent rules (marked with ~) should not appear in the AST
        // So only A and C should be present, not B
        assertEquals(2, ast.children().size());
        assertEquals("A", ast.children().get(0).label());
        assertEquals("C", ast.children().get(1).label());
    }

    @Test
    void characterClassWithSpecialCharacters() {
        // Test characters including dot, underscore, hyphen
        String grammar = """
            Rule <- [a-z.@_]+ ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Rule", "test.name_value@");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void veryLongRuleName() {
        String grammar = """
            ThisIsAVeryLongRuleNameToTestThatLongIdentifiersWork <- "test" ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        assertTrue(rules.containsKey("ThisIsAVeryLongRuleNameToTestThatLongIdentifiersWork"));
    }

    @Test
    void multipleConsecutiveLookaheads() {
        // Multiple positive lookaheads in sequence
        String grammar = """
            Rule <- &[a-z] &[a-c] "a" ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Rule", "a");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        // Should fail for 'd' (doesn't match second lookahead)
        parser = new Parser(rules, "Rule", "d");
        MatchResult matchResult = parser.matchRule("Rule", 0);
        assertTrue(matchResult.isMismatch());
    }

    @Test
    void choiceWithPotentiallyEmptyMatches() {
        // Test choice where alternatives can match varying lengths
        String grammar = """
            Rule <- "a"+ / "b"+ / "" ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // 'aaa' matches first alternative
        Parser parser = new Parser(rules, "Rule", "aaa");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        // 'bbb' matches second alternative
        parser = new Parser(rules, "Rule", "bbb");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        // Empty input matches third alternative
        parser = new Parser(rules, "Rule", "");
        MatchResult matchResult = parser.matchRule("Rule", 0);
        assertFalse(matchResult.isMismatch());
        assertEquals(0, matchResult.len());
    }

    @Test
    void negatedLookaheadWithAlternatives() {
        // Not followed by keyword
        String grammar = """
            Rule <- !(Keyword ![a-z]) [a-z]+ ;
            Keyword <- "if" / "while" / "for" ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        // Regular identifier works
        Parser parser = new Parser(rules, "Rule", "hello");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        // Keyword prefix works (iffy)
        parser = new Parser(rules, "Rule", "iffy");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);

        // Pure keyword should fail
        parser = new Parser(rules, "Rule", "if");
        MatchResult matchResult = parser.matchRule("Rule", 0);
        assertTrue(matchResult.isMismatch());
    }

    @Test
    void repetitionOfGroupedAlternation() {
        // Repeat a choice multiple times
        String grammar = """
            Rule <- ("a" / "b" / "c")+ ;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Rule", "abccbaabccc");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(11, result.len());
    }
}
