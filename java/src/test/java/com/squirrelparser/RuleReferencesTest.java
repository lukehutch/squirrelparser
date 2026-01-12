package com.squirrelparser;

import com.squirrelparser.*;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class RuleReferencesTest {

    @Test
    void simpleRuleReference() {
        String grammar = """
            Main <- A "b";
            A <- "a";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Main", "ab");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(2, result.len());
    }

    @Test
    void multipleRuleReferences() {
        String grammar = """
            Main <- A B C;
            A <- "a";
            B <- "b";
            C <- "c";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Main", "abc");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(3, result.len());
    }

    @Test
    void recursiveRule() {
        String grammar = """
            List <- "a" List / "a";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "List", "a");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(1, result.len());

        parser = new Parser(rules, "List", "aaa");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
        assertEquals(3, result.len());
    }

    @Test
    void mutuallyRecursiveRules() {
        String grammar = """
            A <- "a" B / "a";
            B <- "b" A / "b";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "A", "aba");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(3, result.len());

        parser = new Parser(rules, "A", "bab");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
        assertEquals(3, result.len());
    }

    @Test
    void leftRecursiveRule() {
        String grammar = """
            Expr <- Expr "+" "n" / "n";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "Expr", "n");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(1, result.len());

        parser = new Parser(rules, "Expr", "n+n");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
        assertEquals(3, result.len());

        parser = new Parser(rules, "Expr", "n+n+n");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
        assertEquals(5, result.len());
    }
}
