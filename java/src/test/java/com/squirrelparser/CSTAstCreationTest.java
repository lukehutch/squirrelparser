package com.squirrelparser;

import static com.squirrelparser.SquirrelParser.squirrelParseCST;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

// ============================================================================
// Custom CST Node Classes for Testing
// ============================================================================

/**
 * A simple CST node that includes all its children.
 */
class InclusiveNode extends CSTNodeBase {
    private final String computedValue;

    InclusiveNode(ASTNode astNode, List<CSTNodeBase> children) {
        this(astNode, children, null);
    }

    InclusiveNode(ASTNode astNode, List<CSTNodeBase> children, String computedValue) {
        super(astNode, children);
        this.computedValue = computedValue;
    }

    public String computedValue() {
        return computedValue;
    }
}

/**
 * A CST node that computes from children without storing them.
 */
class ComputedNode extends CSTNodeBase {
    private final int childCount;
    private final String concatenated;

    ComputedNode(ASTNode astNode, List<CSTNodeBase> children, int childCount, String concatenated) {
        super(astNode, List.of());
        this.childCount = childCount;
        this.concatenated = concatenated;
    }

    public int childCount() {
        return childCount;
    }

    public String concatenated() {
        return concatenated;
    }
}

/**
 * A CST node that transforms children.
 */
class TransformedNode extends CSTNodeBase {
    private final List<String> transformedLabels;

    TransformedNode(ASTNode astNode, List<CSTNodeBase> children, List<String> transformedLabels) {
        super(astNode, children);
        this.transformedLabels = transformedLabels;
    }

    public List<String> transformedLabels() {
        return transformedLabels;
    }
}

/**
 * A CST node that selects specific children.
 */
class SelectiveNode extends CSTNodeBase {
    private final List<CSTNodeBase> selectedChildren;

    SelectiveNode(ASTNode astNode, List<CSTNodeBase> children, List<CSTNodeBase> selectedChildren) {
        super(astNode, selectedChildren);
        this.selectedChildren = selectedChildren;
    }

    public List<CSTNodeBase> selectedChildren() {
        return selectedChildren;
    }
}

/**
 * A CST node for terminals.
 */
class TerminalNode extends CSTNodeBase {
    private final String text;

    TerminalNode(ASTNode astNode, String text) {
        super(astNode, List.of());
        this.text = text;
    }

    public String text() {
        return text;
    }
}

/**
 * A CST node for syntax errors.
 */
class ErrorNode extends CSTNodeBase {
    private final String errorMessage;

    ErrorNode(ASTNode astNode, String errorMessage) {
        super(astNode, List.of());
        this.errorMessage = errorMessage;
    }

    public String errorMessage() {
        return errorMessage;
    }
}

/**
 * CST/AST Creation Scenarios tests.
 */
class CSTAstCreationTest {

    // ========================================================================
    // Scenario 1: Factory includes all children (inclusive)
    // ========================================================================

    @Test
    void factoryIncludesAllChildren() {
        String grammar = """
            Expr <- Term ('+' Term)*;
            Term <- [0-9]+;
            """;

        CSTNodeBase cst = squirrelParseCST(
            grammar,
            "Expr",
            Map.of(
                "Expr", (astNode, children) -> new InclusiveNode(astNode, children),
                "Term", (astNode, children) -> new InclusiveNode(astNode, children),
                "<Terminal>", (astNode, children) -> new InclusiveNode(astNode, children)
            ),
            "1+2",
            false
        );

        assertNotNull(cst);
        assertInstanceOf(InclusiveNode.class, cst);
        assertEquals("Expr", cst.label());
        assertTrue(cst.children().size() > 0);
    }

    // ========================================================================
    // Scenario 2: Factory computes from children without storing them
    // ========================================================================

    @Test
    void factoryComputesFromChildrenWithoutStoringThem() {
        String grammar = """
            Sum <- Number ('+' Number)*;
            Number <- [0-9]+;
            """;

        CSTNodeBase cst = squirrelParseCST(
            grammar,
            "Sum",
            Map.of(
                "Sum", (astNode, children) -> {
                    int childCount = children.size();
                    String concatenated = children.stream().map(c -> c.label()).reduce("", (a, b) -> a.isEmpty() ? b : a + "," + b);
                    return new ComputedNode(astNode, children, childCount, concatenated);
                },
                "Number", (astNode, children) -> new ComputedNode(astNode, children, 0, "Number"),
                "<Terminal>", (astNode, children) -> new ComputedNode(astNode, children, 0, "Terminal")
            ),
            "42",
            false
        );

        assertNotNull(cst);
        assertInstanceOf(ComputedNode.class, cst);
        ComputedNode computed = (ComputedNode) cst;
        assertNotNull(computed.childCount());
        assertFalse(computed.concatenated().isEmpty());
    }

    // ========================================================================
    // Scenario 3: Factory transforms children
    // ========================================================================

    @Test
    void factoryTransformsChildren() {
        String grammar = """
            List <- Element (',' Element)*;
            Element <- [a-z]+;
            """;

        CSTNodeBase cst = squirrelParseCST(
            grammar,
            "List",
            Map.of(
                "List", (astNode, children) -> {
                    List<String> labels = children.stream().map(c -> c.label().toUpperCase()).toList();
                    return new TransformedNode(astNode, children, labels);
                },
                "Element", (astNode, children) -> new TransformedNode(astNode, children, List.of("ELEMENT")),
                "<Terminal>", (astNode, children) -> new TransformedNode(astNode, children, List.of("TERMINAL"))
            ),
            "abc",
            false
        );

        assertNotNull(cst);
        assertInstanceOf(TransformedNode.class, cst);
        TransformedNode transformed = (TransformedNode) cst;
        assertFalse(transformed.transformedLabels().isEmpty());
    }

    // ========================================================================
    // Scenario 4: Factory selects specific children
    // ========================================================================

    @Test
    void factorySelectsSpecificChildren() {
        String grammar = """
            Pair <- '(' First ',' Second ')';
            First <- [a-z]+;
            Second <- [0-9]+;
            """;

        CSTNodeBase cst = squirrelParseCST(
            grammar,
            "Pair",
            Map.of(
                "Pair", (astNode, children) -> {
                    // Only keep First and Second, skip terminals
                    List<CSTNodeBase> selected = children.stream()
                        .filter(c -> c.label().equals("First") || c.label().equals("Second"))
                        .toList();
                    return new SelectiveNode(astNode, children, selected);
                },
                "First", (astNode, children) -> new SelectiveNode(astNode, children, children),
                "Second", (astNode, children) -> new SelectiveNode(astNode, children, children),
                "<Terminal>", (astNode, children) -> new SelectiveNode(astNode, children, List.of())
            ),
            "(abc,123)",
            false
        );

        assertNotNull(cst);
        assertInstanceOf(SelectiveNode.class, cst);
        SelectiveNode selective = (SelectiveNode) cst;
        // Should have 2 selected children: First and Second
        assertEquals(2, selective.selectedChildren().size());
    }

    // ========================================================================
    // Scenario 5: Terminal handling
    // ========================================================================

    @Test
    void terminalsAreHandledByFactory() {
        String grammar = """
            Text <- Word;
            Word <- [a-z]+;
            """;

        @SuppressWarnings("unused")
        CSTNodeBase cst = squirrelParseCST(
            grammar,
            "Text",
            Map.of(
                "Text", (astNode, children) -> new InclusiveNode(astNode, children),
                "Word", (astNode, children) -> new InclusiveNode(astNode, children),
                "<Terminal>", (astNode, children) -> new TerminalNode(astNode, "terminal")
            ),
            "hello",
            false
        );

        assertNotNull(cst);
        // Text should have Word children, which have terminal children
        assertFalse(cst.children().isEmpty());
    }

    // ========================================================================
    // Scenario 6: Syntax error handling
    // ========================================================================

    @Test
    void syntaxErrorsAreHandledWhenAllowSyntaxErrorsIsTrue() {
        String grammar = """
            Expr <- Number;
            Number <- [0-9]+;
            """;

        @SuppressWarnings("unused")
        CSTNodeBase cst = squirrelParseCST(
            grammar,
            "Expr",
            Map.of(
                "Expr", (astNode, children) -> new InclusiveNode(astNode, children),
                "Number", (astNode, children) -> new InclusiveNode(astNode, children),
                "<Terminal>", (astNode, children) -> new InclusiveNode(astNode, children),
                "<SyntaxError>", (astNode, children) -> new ErrorNode(astNode, "Syntax error at " + astNode.pos())
            ),
            "abc",
            true
        );

        assertNotNull(cst);
        // With syntax errors allowed, we should get an error node
    }

    // ========================================================================
    // Scenario 7: Nested structures with mixed approaches
    // ========================================================================

    @Test
    void nestedStructuresWithMixedFactoryApproaches() {
        String grammar = """
            Doc <- Section+;
            Section <- Title;
            Title <- [a-z]+;
            """;

        @SuppressWarnings("unused")
        CSTNodeBase cst = squirrelParseCST(
            grammar,
            "Doc",
            Map.of(
                // Inclusive factory
                "Doc", (astNode, children) -> new InclusiveNode(astNode, children),
                // Selective factory
                "Section", (astNode, children) -> {
                    List<CSTNodeBase> selected = children.stream()
                        .filter(c -> c.label().equals("Title"))
                        .toList();
                    return new SelectiveNode(astNode, children, selected);
                },
                // Computed factory
                "Title", (astNode, children) -> new ComputedNode(astNode, children, children.size(), "Title"),
                // Terminal factory
                "<Terminal>", (astNode, children) -> new TerminalNode(astNode, "terminal")
            ),
            "abc",
            false
        );

        assertNotNull(cst);
        assertInstanceOf(InclusiveNode.class, cst);
    }

    // ========================================================================
    // Scenario 8: Empty alternatives and optional matching
    // ========================================================================

    @Test
    void handlesOptionalMatchesWithoutErrors() {
        String grammar = """
            Sentence <- Word (' ' Word)*;
            Word <- [a-z]+;
            """;

        CSTNodeBase cst = squirrelParseCST(
            grammar,
            "Sentence",
            Map.of(
                "Sentence", (astNode, children) -> new InclusiveNode(astNode, children),
                "Word", (astNode, children) -> new InclusiveNode(astNode, children),
                "<Terminal>", (astNode, children) -> new InclusiveNode(astNode, children)
            ),
            "hello world test",
            false
        );

        assertNotNull(cst);
    }
}
