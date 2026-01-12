package com.squirrelparser.tree;

import java.util.List;
import java.util.Map;

import com.squirrelparser.clause.terminal.Terminal;

/**
 * Build a CST from an AST.
 */
public final class CSTBuilder {
    private CSTBuilder() {}

    /**
     * Build a CST from an AST using the provided factory map.
     *
     * <p>The factories map should contain an entry for each rule name in the grammar, plus:
     * <ul>
     *   <li>'&lt;Terminal&gt;' for terminal matches (string literals, character classes, etc.)</li>
     *   <li>'&lt;SyntaxError&gt;' if allowSyntaxErrors is true</li>
     * </ul>
     *
     * @param ast The AST to convert
     * @param factories Map from rule name to factory function
     * @param allowSyntaxErrors Whether to allow syntax errors
     * @return The CST root node
     */
    public static CSTNode buildCST(
            ASTNode ast,
            Map<String, CSTNodeFactoryFn> factories,
            boolean allowSyntaxErrors) {
        return buildCSTInternal(ast, factories, allowSyntaxErrors);
    }

    private static CSTNode buildCSTInternal(
            ASTNode ast,
            Map<String, CSTNodeFactoryFn> factories,
            boolean allowSyntaxErrors) {
        if (ast.syntaxError() != null) {
            if (!allowSyntaxErrors) {
                throw new IllegalArgumentException("Syntax error: " + ast.syntaxError());
            }
            var errorFactory = factories.get("<SyntaxError>");
            if (errorFactory == null) {
                throw new IllegalArgumentException("No factory found for <SyntaxError>");
            }
            return errorFactory.apply(ast, List.of());
        }

        var factory = factories.get(ast.label());

        if (factory == null && ast.label().equals(Terminal.NODE_LABEL)) {
            factory = factories.get("<Terminal>");
        }

        if (factory == null) {
            throw new IllegalArgumentException("No factory found for rule \"" + ast.label() + "\"");
        }

        List<CSTNode> childCSTNodes = ast.children().stream()
            .map(child -> buildCSTInternal(child, factories, allowSyntaxErrors))
            .toList();
        return factory.apply(ast, childCSTNodes);
    }
}
