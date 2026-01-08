package com.squirrelparser;

import java.util.ArrayList;
import java.util.List;

import com.squirrelparser.Combinators.Ref;
import com.squirrelparser.Terminals.AnyChar;
import com.squirrelparser.Terminals.Char;
import com.squirrelparser.Terminals.CharRange;
import com.squirrelparser.Terminals.Str;
import com.squirrelparser.Terminals.Terminal;

/**
 * AST Node representing a parsed match.
 */
public class ASTNode {
    public final String label;
    public final int pos;
    public final int len;
    public final List<ASTNode> children;
    private final String input;

    public ASTNode(String label, int pos, int len, List<ASTNode> children, String input) {
        this.label = label;
        this.pos = pos;
        this.len = len;
        this.children = children;
        this.input = input;
    }

    public String text() {
        return input.substring(pos, pos + len);
    }

    @Override
    public String toString() {
        return "ASTNode(" + label + ", \"" + text() + "\", children: " + children.size() + ")";
    }

    public String toPrettyString() {
        return toPrettyString(0);
    }

    private String toPrettyString(int indent) {
        StringBuilder buffer = new StringBuilder();
        buffer.append("  ".repeat(indent));
        buffer.append(label);
        if (children.isEmpty()) {
            buffer.append(": \"").append(text()).append("\"");
        }
        buffer.append("\n");
        for (ASTNode child : children) {
            buffer.append(child.toPrettyString(indent + 1));
        }
        return buffer.toString();
    }

    /**
     * Build an AST from a parse tree.
     *
     * For top-level combinator matches, creates a synthetic node with the given topRule label.
     *
     * @param match The match result
     * @param input The input string
     * @param topRule Optional rule name for synthetic top-level nodes (combinators)
     * @return The AST node, or null if match is null/mismatch and no topRule provided
     */
    public static ASTNode buildAST(MatchResult match, String input, String topRule) {
        if (match == null || match.isMismatch()) {
            return null;
        }
        ASTNode ast = buildASTNode(match, input);

        // If top-level match is a combinator and we have a topRule label, build synthetic node
        if (ast == null && topRule != null) {
            java.util.List<ASTNode> children = collectChildrenForAST(match, input);
            ast = new ASTNode(topRule, match.pos(), match.len(), children, input);
        }

        return ast;
    }

    /**
     * Build an AST from a parse tree (without synthetic top-level node handling).
     */
    public static ASTNode buildAST(MatchResult match, String input) {
        if (match == null || match.isMismatch()) {
            return null;
        }
        return buildASTNode(match, input);
    }

    private static ASTNode buildASTNode(MatchResult match, String input) {
        Clause clause = match.clause();

        // Handle Ref nodes - these become AST nodes with the rule name as label
        // UNLESS they're marked as transparent, in which case we flatten them
        if (clause instanceof Ref ref) {
            if (ref.transparent()) {
                // Transparent rule - don't create a node, just return null
                return null;
            }
            // Get children by recursively processing the wrapped match
            List<ASTNode> children = collectChildren(match, input);
            return new ASTNode(ref.ruleName(), match.pos(), match.len(), children, input);
        }

        // Handle terminal nodes - these become leaf AST nodes
        if (clause instanceof Str || clause instanceof Char ||
            clause instanceof CharRange || clause instanceof AnyChar) {
            return new ASTNode(clause.getClass().getSimpleName(), match.pos(), match.len(), List.of(), input);
        }

        // For all other nodes (combinators), flatten and collect children
        return null;
    }

    /**
     * Collect children for an AST node by flattening combinators.
     */
    private static List<ASTNode> collectChildren(MatchResult match, String input) {
        List<ASTNode> result = new ArrayList<>();

        for (MatchResult child : match.subClauseMatches()) {
            if (child.isMismatch() || (child instanceof SyntaxError)) {
                continue;
            }

            Clause clause = child.clause();

            // If child is a Ref or terminal, add it as an AST node
            if (clause instanceof Ref || clause instanceof Terminal) {
                ASTNode node = buildASTNode(child, input);
                if (node != null) {
                    result.add(node);
                }
            }
            // Otherwise, it's a combinator - recursively collect its children
            else {
                result.addAll(collectChildren(child, input));
            }
        }

        return result;
    }

    /**
     * Collect children for AST building when top-level match is a combinator.
     */
    public static List<ASTNode> collectChildrenForAST(MatchResult match, String input) {
        List<ASTNode> result = new ArrayList<>();

        for (MatchResult child : match.subClauseMatches()) {
            if (child.isMismatch() || (child instanceof SyntaxError)) {
                continue;
            }

            Clause clause = child.clause();

            // If child is a Ref, create an AST node for it (unless transparent)
            if (clause instanceof Ref ref) {
                if (!ref.transparent()) {
                    List<ASTNode> children = collectChildren(child, input);
                    result.add(new ASTNode(ref.ruleName(), child.pos(), child.len(), children, input));
                }
                // Transparent rules are completely skipped - don't create node and don't include their children
            }
            // Include terminals as leaf nodes
            else if (clause instanceof Terminal) {
                ASTNode node = buildASTNode(child, input);
                if (node != null) {
                    result.add(node);
                }
            }
            // For other combinators, recursively collect their children
            else {
                result.addAll(collectChildrenForAST(child, input));
            }
        }

        return result;
    }
}
