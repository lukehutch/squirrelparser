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
 * Factory for creating CST nodes from AST nodes.
 */
record CSTNodeFactory(String ruleName, BiFunction<ASTNode, List<CSTNodeBase>, CSTNodeBase> factory) {}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Build a CST from an AST.
 */
final class CSTBuilder {
    private CSTBuilder() {}

    public static CSTNodeBase buildCST(ASTNode ast, List<CSTNodeFactory> factories, boolean allowSyntaxErrors) {
        var factoriesMap = new java.util.HashMap<String, CSTNodeFactory>();
        for (var factory : factories) {
            if (factoriesMap.containsKey(factory.ruleName())) {
                throw new IllegalArgumentException("Duplicate factory for rule \"" + factory.ruleName() + "\"");
            }
            factoriesMap.put(factory.ruleName(), factory);
        }
        return buildCSTInternal(ast, factoriesMap, allowSyntaxErrors);
    }

    private static CSTNodeBase buildCSTInternal(ASTNode ast, java.util.Map<String, CSTNodeFactory> factoriesMap,
                                                  boolean allowSyntaxErrors) {
        if (ast.syntaxError() != null) {
            if (!allowSyntaxErrors) {
                throw new IllegalArgumentException("Syntax error: " + ast.syntaxError());
            }
            var errorFactory = factoriesMap.get("<SyntaxError>");
            if (errorFactory == null) {
                throw new IllegalArgumentException("No factory found for <SyntaxError>");
            }
            return errorFactory.factory().apply(ast, List.of());
        }

        var factory = factoriesMap.get(ast.label());

        if (factory == null && ast.label().equals(Terminal.NODE_LABEL)) {
            factory = factoriesMap.get("<Terminal>");
        }

        if (factory == null) {
            throw new IllegalArgumentException("No factory found for rule \"" + ast.label() + "\"");
        }

        List<CSTNodeBase> childCSTNodes = ast.children().stream()
            .map(child -> buildCSTInternal(child, factoriesMap, allowSyntaxErrors))
            .toList();
        return factory.factory().apply(ast, childCSTNodes);
    }
}
