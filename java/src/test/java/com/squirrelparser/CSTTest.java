package com.squirrelparser;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static com.squirrelparser.SquirrelParser.*;

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
        List<CSTNodeFactory> factories = List.of(
            new CSTNodeFactory("Greeting", (astNode, children) ->
                new SimpleCST(astNode, children)
            )
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
        List<CSTNodeFactory> factories = List.of(
            new CSTNodeFactory("Greeting", (astNode, children) ->
                new SimpleCST(astNode, children)
            ),
            new CSTNodeFactory("ExtraRule", (astNode, children) ->
                new SimpleCST(astNode, children)
            )
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

        List<CSTNodeFactory> factories = List.of(
            new CSTNodeFactory("Main", (astNode, children) ->
                new SimpleCST(astNode, children)
            ),
            new CSTNodeFactory("Item", (astNode, children) ->
                new SimpleCST(astNode, children, "test")
            ),
            new CSTNodeFactory("<Terminal>", (astNode, children) ->
                new SimpleCST(astNode, children)
            )
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

        List<CSTNodeFactory> factories = List.of(
            new CSTNodeFactory("Test", (astNode, children) ->
                new SimpleCST(astNode, children, "hello")
            ),
            new CSTNodeFactory("<Terminal>", (astNode, children) ->
                new SimpleCST(astNode, children)
            )
        );

        CSTNodeBase cst = squirrelParseCST(grammar, "Test", factories, "hello", false);

        assertNotNull(cst);
        assertEquals("Test", cst.label());
    }

    @Test
    void duplicateRuleNamesThrowArgumentError() {
        String grammar = """
            Main <- "test";
            """;

        // Provide two factories with the same rule name
        List<CSTNodeFactory> factories = List.of(
            new CSTNodeFactory("Main", (astNode, children) ->
                new SimpleCST(astNode, children)
            ),
            new CSTNodeFactory("Main", (astNode, children) ->
                new SimpleCST(astNode, children)
            )
        );

        assertThrows(IllegalArgumentException.class, () ->
            squirrelParseCST(grammar, "Main", factories, "test", false)
        );
    }

    @Test
    void transparentRulesAreExcludedFromCSTFactories() {
        String grammar = """
            Expr <- ~Whitespace Term ~Whitespace;
            ~Whitespace <- ' '*;
            Term <- "x";
            """;

        // Should only need factories for Expr and Term, not Whitespace (which is transparent)
        List<CSTNodeFactory> factories = List.of(
            new CSTNodeFactory("Expr", (astNode, children) ->
                new SimpleCST(astNode, children)
            ),
            new CSTNodeFactory("Term", (astNode, children) ->
                new SimpleCST(astNode, children, "x")
            ),
            new CSTNodeFactory("<Terminal>", (astNode, children) ->
                new SimpleCST(astNode, children)
            )
        );

        // This should work without a factory for Whitespace
        CSTNodeBase cst = squirrelParseCST(grammar, "Expr", factories, " x ", false);

        assertNotNull(cst);
    }
}
