package com.squirrelparser.tree;

import java.util.List;

import com.squirrelparser.parser.SyntaxError;

/**
 * Base class for AST and CST nodes.
 */
public abstract class Node<T extends Node<T>> {
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

