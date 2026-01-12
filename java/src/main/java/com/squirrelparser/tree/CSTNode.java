package com.squirrelparser.tree;

import java.util.List;

/**
 * Base class for CST nodes.
 */
public abstract class CSTNode extends Node<CSTNode> {
    protected CSTNode(ASTNode astNode, List<CSTNode> children) {
        super(astNode.label(), astNode.pos(), astNode.len(), astNode.syntaxError(), children);
    }
}
