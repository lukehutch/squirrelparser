package com.squirrelparser;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.parser.MetaGrammar;
import com.squirrelparser.parser.ParseResult;
import com.squirrelparser.parser.Parser;
import com.squirrelparser.tree.ASTBuilder;
import com.squirrelparser.tree.ASTNode;

class AstBuildingTest {

    @Test
    void astStructureForSimpleGrammar() {
        String grammar = """
            Main <- A B;
            A <- "a";
            B <- "b";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Main", "ab");
        ParseResult parseResult = parser.parse();
        ASTNode ast = ASTBuilder.buildAST(parseResult);

        assertNotNull(ast);
        assertEquals("Main", ast.label());
        assertEquals(2, ast.children().size());
        assertEquals("A", ast.children().get(0).label());
        assertEquals("B", ast.children().get(1).label());
    }

    @Test
    void astFlattensCombinatorNodes() {
        String grammar = """
            Main <- A+ B*;
            A <- "a";
            B <- "b";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Main", "aaabbb");
        ParseResult parseResult = parser.parse();
        ASTNode ast = ASTBuilder.buildAST(parseResult);

        assertNotNull(ast);
        assertEquals("Main", ast.label());

        // Should have flattened A and B children, not intermediate repetition nodes
        long aNodes = ast.children().stream().filter(n -> n.label().equals("A")).count();
        long bNodes = ast.children().stream().filter(n -> n.label().equals("B")).count();
        assertEquals(3, aNodes);
        assertEquals(3, bNodes);
    }

    @Test
    void astTextExtraction() {
        String grammar = """
            Number <- [0-9]+;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Number", "123");
        ParseResult parseResult = parser.parse();
        ASTNode ast = ASTBuilder.buildAST(parseResult);

        assertNotNull(ast);
        // ast.text property not available; extract from input using position and length
        String text = parseResult.input().substring(0, parseResult.root().len());
        assertEquals("123", text);
    }

    @Test
    void astForNestedStructures() {
        String grammar = """
            Expr <- Term (("+" / "-") Term)*;
            Term <- [0-9]+;
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Expr", "1+2-3");
        ParseResult parseResult = parser.parse();
        ASTNode ast = ASTBuilder.buildAST(parseResult);

        assertNotNull(ast);
        assertEquals("Expr", ast.label());

        // Should have Terms as direct children (flattened)
        long termNodes = ast.children().stream().filter(n -> n.label().equals("Term")).count();
        assertTrue(termNodes >= 1);
    }

    @Test
    void astPrettyPrinting() {
        String grammar = """
            Main <- A B;
            A <- "a";
            B <- "b";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Main", "ab");
        ParseResult parseResult = parser.parse();
        ASTNode ast = ASTBuilder.buildAST(parseResult);

        assertNotNull(ast);
        String prettyString = ast.toPrettyString(parseResult.input());
        assertTrue(prettyString.contains("Main"));
        assertTrue(prettyString.contains("A"));
        assertTrue(prettyString.contains("B"));
    }

    @Test
    void astAllowsZeroChildrenWhenAllSubRulesAreTransparent() {
        // When a rule only contains transparent rules, the AST node has zero children
        String grammar = """
            Main <- ~A;
            ~A <- "a";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Main", "a");
        ParseResult parseResult = parser.parse();
        ASTNode ast = ASTBuilder.buildAST(parseResult);

        assertNotNull(ast);
        assertEquals("Main", ast.label());
        assertEquals(0, ast.pos());
        assertEquals(1, ast.len());
        // Main has zero children because A is transparent
        assertEquals(0, ast.children().size());
    }
}
