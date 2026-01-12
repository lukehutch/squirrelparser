package com.squirrelparser.tree;

import java.util.List;
import java.util.function.BiFunction;

/**
 * Factory function type for creating CST nodes from AST nodes.
 */
@FunctionalInterface
public interface CSTNodeFactoryFn extends BiFunction<ASTNode, List<CSTNode>, CSTNode> {}
