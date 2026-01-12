package com.squirrelparser;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.function.BiFunction;

/**
 * Base class for AST and CST nodes.
 */
abstract class Node<T extends Node<T>> {
    private final String label;
    private final int pos;
    private final int len;
    private final SyntaxError syntaxError;
    private final List<T> children;

    protected Node(String label, int pos, int len, SyntaxError syntaxError, List<T> children) {
        this.label = label;
        this.pos = pos;
        this.len = len;
        this.syntaxError = syntaxError;
        this.children = children;
    }

    public String label() { return label; }
    public int pos() { return pos; }
    public int len() { return len; }
    public SyntaxError syntaxError() { return syntaxError; }
    public List<T> children() { return children; }

    public String getInputSpan(String input) {
        return input.substring(pos, pos + len);
    }

    @Override
    public String toString() {
        return label + ": pos: " + pos + ", len: " + len;
    }

    public String toPrettyString(String input) {
        var buffer = new StringBuilder();
        buildTree(input, "", buffer, true);
        return buffer.toString();
    }

    protected void buildTree(String input, String prefix, StringBuilder buffer, boolean isRoot) {
        if (!isRoot) {
            buffer.append("\n");
        }
        buffer.append(prefix);
        buffer.append(label);
        if (children.isEmpty()) {
            buffer.append(": \"").append(getInputSpan(input)).append("\"");
        }

        for (int i = 0; i < children.size(); i++) {
            boolean isLast = i == children.size() - 1;
            String childPrefix = prefix + (isRoot ? "" : (isLast ? "    " : "|   "));
            String connector = isLast ? "`---" : "|---";

            buffer.append("\n");
            buffer.append(prefix);
            buffer.append(isRoot ? "" : connector);

            children.get(i).buildTree(input, childPrefix, buffer, false);
        }
    }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Build an AST from a parse tree.
 */
final class ASTBuilder {
    private ASTBuilder() {}

    public static ASTNode buildAST(ParseResult parseResult) {
        ASTNode extraNode = parseResult.unmatchedInput() != null
            ? ASTNode.syntaxError(parseResult.unmatchedInput())
            : null;

        return newASTNode(
            parseResult.topRuleName(),
            parseResult.root(),
            parseResult.transparentRules(),
            extraNode
        );
    }

    private static ASTNode newASTNode(String label, MatchResult refdMatchResult,
                                       Set<String> transparentRules, ASTNode addExtraASTNode) {
        List<ASTNode> childASTNodes = new ArrayList<>();
        collectChildASTNodes(refdMatchResult, childASTNodes, transparentRules);
        if (addExtraASTNode != null) {
            childASTNodes.add(addExtraASTNode);
        }
        return ASTNode.nonTerminal(label, childASTNodes);
    }

    private static void collectChildASTNodes(MatchResult matchResult,
                                              List<ASTNode> collectedAstNodes,
                                              Set<String> transparentRules) {
        if (matchResult.isMismatch()) {
            return;
        }
        if (matchResult instanceof SyntaxError se) {
            collectedAstNodes.add(ASTNode.syntaxError(se));
        } else {
            Clause clause = matchResult.clause();
            if (clause instanceof Terminal) {
                collectedAstNodes.add(ASTNode.terminal(matchResult));
            } else if (clause instanceof Ref ref) {
                if (!transparentRules.contains(ref.ruleName())) {
                    collectedAstNodes.add(newASTNode(
                        ref.ruleName(),
                        matchResult.subClauseMatches().getFirst(),
                        transparentRules,
                        null
                    ));
                }
            } else {
                for (MatchResult subClauseMatch : matchResult.subClauseMatches()) {
                    collectChildASTNodes(subClauseMatch, collectedAstNodes, transparentRules);
                }
            }
        }
    }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Base class for CST nodes.
 */
abstract class CSTNodeBase extends Node<CSTNodeBase> {
    protected CSTNodeBase(ASTNode astNode, List<CSTNodeBase> children) {
        super(astNode.label(), astNode.pos(), astNode.len(), astNode.syntaxError(), children);
    }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Factory function type for creating CST nodes from AST nodes.
 */
@FunctionalInterface
interface CSTNodeFactoryFn extends BiFunction<ASTNode, List<CSTNodeBase>, CSTNodeBase> {}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Build a CST from an AST.
 */
final class CSTBuilder {
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
    public static CSTNodeBase buildCST(
            ASTNode ast,
            java.util.Map<String, CSTNodeFactoryFn> factories,
            boolean allowSyntaxErrors) {
        return buildCSTInternal(ast, factories, allowSyntaxErrors);
    }

    private static CSTNodeBase buildCSTInternal(
            ASTNode ast,
            java.util.Map<String, CSTNodeFactoryFn> factories,
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

        List<CSTNodeBase> childCSTNodes = ast.children().stream()
            .map(child -> buildCSTInternal(child, factories, allowSyntaxErrors))
            .toList();
        return factory.apply(ast, childCSTNodes);
    }
}
