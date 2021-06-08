package squirrelparser.node;

import java.util.ArrayList;
import java.util.List;

import squirrelparser.clause.Clause;
import squirrelparser.utils.TreePrinter;

/** A node in the Abstract Syntax Tree (AST). */
public class ASTNode {
    public final String label;
    public final Clause clause;
    public final int pos;
    public final int len;
    public final CharSequence text;
    public final List<ASTNode> children = new ArrayList<>();

    private ASTNode(String label, Clause clause, int pos, int len, CharSequence text) {
        this.label = label == null ? "<root>" : label;
        this.clause = clause;
        this.pos = pos;
        this.len = len;
        this.text = text;
    }

    /** Recursively create an AST from a parse tree. */
    public ASTNode(Match match, String input) {
        this(match.clause.astNodeLabel, match.clause, match.pos, match.len,
                input.subSequence(match.pos, Math.min(input.length(), match.pos + match.len)));
        addNodesWithASTNodeLabelsRecursive(this, match, input);
    }

    /** Recursively convert a match node to an AST node. */
    private static void addNodesWithASTNodeLabelsRecursive(ASTNode parentASTNode, Match parentMatch, String input) {
        // Recurse to descendants
        for (int subClauseMatchIdx = 0; subClauseMatchIdx < parentMatch.subClauseMatches
                .size(); subClauseMatchIdx++) {
            var subClauseMatch = parentMatch.subClauseMatches.get(subClauseMatchIdx);
            if (subClauseMatch.clause.astNodeLabel != null) {
                // Create an AST node for any labeled sub-clauses
                parentASTNode.children.add(new ASTNode(subClauseMatch, input));
            } else {
                // Do not add an AST node for parse tree nodes that are not labeled; however, still need
                // to recurse to their subclause matches
                addNodesWithASTNodeLabelsRecursive(parentASTNode, subClauseMatch, input);
            }
        }
    }

    /**
     * @return The only child of this AST node.
     * 
     * @throws IllegalArgumentException if this AST node does not have exactly one child.
     */
    public ASTNode getOnlyChild() {
        if (children.size() != 1) {
            throw new IllegalArgumentException("Expected one child, got " + children.size());
        }
        return children.get(0);
    }

    /**
     * @return The first child of this AST node.
     * 
     * @throws IllegalArgumentException if this AST node does not have at least one child.
     */
    public ASTNode getFirstChild() {
        return getChild(0);
    }

    /**
     * @return The second child of this AST node.
     * 
     * @throws IllegalArgumentException if this AST node does not have at least two children.
     */
    public ASTNode getSecondChild() {
        return getChild(1);
    }

    /**
     * @return The third child of this AST node.
     * 
     * @throws IllegalArgumentException if this AST node does not have at least three children.
     */
    public ASTNode getThirdChild() {
        return getChild(2);
    }

    /**
     * @return The i-th child of this AST node (zero-indexed).
     * 
     * @throws IllegalArgumentException if this AST node does not have at least i+1 children.
     */
    public ASTNode getChild(int i) {
        if (children.size() < i + 1) {
            throw new IllegalArgumentException(
                    "ASTNode does not have enough children: i = " + i + "; children.size() = " + children.size());
        }
        return children.get(i);
    }

    /** Get the subsequence of the input matched by this AST node. */
    public String getText() {
        return text.toString();
    }

    /** Render the AST into ASCII art form. */
    public String toStringWholeTree() {
        StringBuilder buf = new StringBuilder();
        TreePrinter.renderTreeView(this, "", true, buf);
        return buf.toString();
    }

    @Override
    public String toString() {
        return clause + ":" + pos + "+" + len;
    }
}
