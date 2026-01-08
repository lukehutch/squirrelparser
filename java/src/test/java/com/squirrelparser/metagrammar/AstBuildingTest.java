package com.squirrelparser.metagrammar;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.ASTNode;
import com.squirrelparser.Clause;
import com.squirrelparser.MetaGrammar;
import com.squirrelparser.Parser;

/**
 * MetaGrammar - AST Building Tests
 * Port of ast_building_test.dart
 */
class AstBuildingTest {

    @Test
    void testASTStructureForSimpleGrammar() {
        String grammar = """
            Main <- A B;
            A <- "a";
            B <- "b";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "ab");
        ASTNode ast = parser.parseToAST("Main");

        assertNotNull(ast);
        assertEquals("Main", ast.label);
        assertEquals(2, ast.children.size());
        assertEquals("A", ast.children.get(0).label);
        assertEquals("B", ast.children.get(1).label);
    }

    @Test
    void testASTFlattensCombinatorNodes() {
        String grammar = """
            Main <- A+ B*;
            A <- "a";
            B <- "b";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "aaabbb");
        ASTNode ast = parser.parseToAST("Main");

        assertNotNull(ast);
        assertEquals("Main", ast.label);

        // Should have flattened A and B children, not intermediate repetition nodes
        long aNodes = ast.children.stream().filter(n -> n.label.equals("A")).count();
        long bNodes = ast.children.stream().filter(n -> n.label.equals("B")).count();
        assertEquals(3, aNodes);
        assertEquals(3, bNodes);
    }

    @Test
    void testASTTextExtraction() {
        String grammar = """
            Number <- [0-9]+;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "123");
        ASTNode ast = parser.parseToAST("Number");

        assertNotNull(ast);
        assertEquals("123", ast.text());
    }

    @Test
    void testASTForNestedStructures() {
        String grammar = """
            Expr <- Term (("+" / "-") Term)*;
            Term <- [0-9]+;
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "1+2-3");
        ASTNode ast = parser.parseToAST("Expr");

        assertNotNull(ast);
        assertEquals("Expr", ast.label);

        // Should have Terms as direct children (flattened)
        long termNodes = ast.children.stream().filter(n -> n.label.equals("Term")).count();
        assertTrue(termNodes >= 1);
    }

    @Test
    void testASTPrettyPrinting() {
        String grammar = """
            Main <- A B;
            A <- "a";
            B <- "b";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "ab");
        ASTNode ast = parser.parseToAST("Main");

        assertNotNull(ast);
        String prettyString = ast.toPrettyString();
        assertTrue(prettyString.contains("Main"));
        assertTrue(prettyString.contains("A"));
        assertTrue(prettyString.contains("B"));
    }
}
