package com.squirrelparser;

import static com.squirrelparser.SquirrelParser.squirrelParseCST;
import static com.squirrelparser.SquirrelParser.squirrelParsePT;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

/**
 * Simple test CST node for testing.
 */
class SimpleCST extends CSTNodeBase {
    private final String value;

    SimpleCST(ASTNode astNode, List<CSTNodeBase> children) {
        this(astNode, children, null);
    }

    SimpleCST(ASTNode astNode, List<CSTNodeBase> children, String value) {
        super(astNode, children);
        this.value = value;
    }

    public String value() {
        return value;
    }
}

/**
 * CST - Concrete Syntax Tree tests.
 */
class CSTTest {

    @Test
    void parseTreeMethodsExistAndWork() {
        String grammar = """
            Greeting <- "hello" Name;
            Name <- [a-z]+;
            """;

        ParseResult parseResult = squirrelParsePT(grammar, "Greeting", "helloworld");

        assertNotNull(parseResult);
        assertFalse(parseResult.root().isMismatch());
        assertTrue(parseResult.getSyntaxErrors().isEmpty());
    }

    @Test
    void cstFactoryValidationCatchesMissingFactories() {
        String grammar = """
            Greeting <- "hello" Name;
            Name <- [a-z]+;
            """;

        // Only provide factory for Greeting, missing Name and <Terminal>
        Map<String, CSTNodeFactoryFn> factories = Map.of(
            "Greeting", (astNode, children) -> new SimpleCST(astNode, children)
        );

        assertThrows(IllegalArgumentException.class, () ->
            squirrelParseCST(grammar, "Greeting", factories, "hello world", false)
        );
    }

    @Test
    void cstFactoryValidationCatchesExtraFactories() {
        String grammar = """
            Greeting <- "hello";
            """;

        // Provide factory for Greeting and extra Name
        Map<String, CSTNodeFactoryFn> factories = Map.of(
            "Greeting", (astNode, children) -> new SimpleCST(astNode, children),
            "ExtraRule", (astNode, children) -> new SimpleCST(astNode, children)
        );

        assertThrows(IllegalArgumentException.class, () ->
            squirrelParseCST(grammar, "Greeting", factories, "hello", false)
        );
    }

    @Test
    void basicCSTConstructionWorks() {
        String grammar = """
            Main <- Item;
            Item <- "test";
            """;

        Map<String, CSTNodeFactoryFn> factories = Map.of(
            "Main", (astNode, children) -> new SimpleCST(astNode, children),
            "Item", (astNode, children) -> new SimpleCST(astNode, children, "test"),
            "<Terminal>", (astNode, children) -> new SimpleCST(astNode, children)
        );

        CSTNodeBase cst = squirrelParseCST(grammar, "Main", factories, "test", false);

        assertNotNull(cst);
        assertEquals("Main", cst.label());
    }

    @Test
    void squirrelParseIsTheMainPublicAPI() {
        String grammar = """
            Test <- "hello";
            """;

        Map<String, CSTNodeFactoryFn> factories = Map.of(
            "Test", (astNode, children) -> new SimpleCST(astNode, children, "hello"),
            "<Terminal>", (astNode, children) -> new SimpleCST(astNode, children)
        );

        CSTNodeBase cst = squirrelParseCST(grammar, "Test", factories, "hello", false);

        assertNotNull(cst);
        assertEquals("Test", cst.label());
    }

    @Test
    void transparentRulesAreExcludedFromCSTFactories() {
        String grammar = """
            Expr <- ~Whitespace Term ~Whitespace;
            ~Whitespace <- ' '*;
            Term <- "x";
            """;

        // Should only need factories for Expr and Term, not Whitespace (which is transparent)
        Map<String, CSTNodeFactoryFn> factories = Map.of(
            "Expr", (astNode, children) -> new SimpleCST(astNode, children),
            "Term", (astNode, children) -> new SimpleCST(astNode, children, "x"),
            "<Terminal>", (astNode, children) -> new SimpleCST(astNode, children)
        );

        // This should work without a factory for Whitespace
        CSTNodeBase cst = squirrelParseCST(grammar, "Expr", factories, " x ", false);

        assertNotNull(cst);
    }
}
