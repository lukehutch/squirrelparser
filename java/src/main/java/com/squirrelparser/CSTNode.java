package com.squirrelparser;

/**
 * Base class for all CST nodes.
 *
 * CST nodes represent the concrete syntax structure of the input, with each node
 * corresponding to a grammar rule (non-transparent rules only) or a terminal.
 */
public abstract class CSTNode {
    protected final String name;

    /**
     * Initialize a CST node.
     *
     * @param name The name of this node (rule name or `<Terminal>`)
     */
    public CSTNode(String name) {
        this.name = name;
    }

    /**
     * Get the name of this node.
     */
    public String getName() {
        return name;
    }

    @Override
    public String toString() {
        return name;
    }
}
