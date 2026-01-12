package com.squirrelparser.tree;

import java.util.List;

import com.squirrelparser.clause.terminal.Terminal;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.SyntaxError;

/**
 * An AST node representing either a rule match or a terminal match.
 */
public final class ASTNode extends Node<ASTNode> {
    private ASTNode(String label, int pos, int len, SyntaxError syntaxError, List<ASTNode> children) {
        super(label, pos, len, syntaxError, children);
    }

    static ASTNode terminal(MatchResult terminalMatch) {
        return new ASTNode(Terminal.NODE_LABEL, terminalMatch.pos(), terminalMatch.len(), null, List.of());
    }

    static ASTNode nonTerminal(String label, int pos, int len, List<ASTNode> children) {
        return new ASTNode(label, pos, len, null, children);
    }

    static ASTNode syntaxError(SyntaxError se) {
        return new ASTNode(SyntaxError.NODE_LABEL, se.pos(), se.len(), se, List.of());
    }

    // Public factory for creating nodes in tests/CST building
    public static ASTNode of(String label, int pos, int len, List<ASTNode> children) {
        return new ASTNode(label, pos, len, null, children);
    }
}
