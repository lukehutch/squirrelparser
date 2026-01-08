package com.squirrelparser;

import java.util.List;
import java.util.function.BiFunction;

/**
 * Metadata for creating a CST node from a parse tree node.
 *
 * Each grammar rule (non-transparent) must have a corresponding factory.
 * The factory takes the rule name, expected child names, and actual child CST nodes,
 * and returns a CSTNode instance of type T.
 *
 * @param <T> The specific CST node type that this factory produces.
 *            Must be a subtype of CSTNode.
 */
public class CSTNodeFactory<T extends CSTNode> {
    private final String ruleName;
    private final List<String> expectedChildren;
    private final CSTNodeFactoryFunction<T> factory;

    /**
     * Functional interface for CST node factory functions.
     *
     * @param <T> The specific CST node type that this factory produces.
     */
    @FunctionalInterface
    public interface CSTNodeFactoryFunction<T extends CSTNode> {
        /**
         * Create a CST node of type T from rule name, expected child names,
         * and actual child CST nodes.
         *
         * @param ruleName The name of the grammar rule
         * @param expectedChildNames The expected child node names or `<Terminal>` for terminal children
         * @param children The actual child CST nodes
         * @return The created CST node
         */
        T create(String ruleName, List<String> expectedChildNames, List<CSTNode> children);
    }

    /**
     * Initialize a CST node factory.
     *
     * @param ruleName The grammar rule name this factory corresponds to
     * @param expectedChildren The expected child node names or `<Terminal>` for terminal children
     * @param factory Factory function that creates a CST node of type T from rule name,
     *               expected child names, and actual child CST nodes
     */
    public CSTNodeFactory(
        String ruleName,
        List<String> expectedChildren,
        CSTNodeFactoryFunction<T> factory
    ) {
        this.ruleName = ruleName;
        this.expectedChildren = expectedChildren;
        this.factory = factory;
    }

    /**
     * Get the rule name.
     */
    public String getRuleName() {
        return ruleName;
    }

    /**
     * Get the expected children.
     */
    public List<String> getExpectedChildren() {
        return expectedChildren;
    }

    /**
     * Create a CST node using this factory.
     */
    public T create(String ruleName, List<String> expectedChildNames, List<CSTNode> children) {
        return factory.create(ruleName, expectedChildNames, children);
    }
}
