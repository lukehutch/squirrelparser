package com.squirrelparser.tree;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

import com.squirrelparser.clause.Clause;
import com.squirrelparser.clause.nonterminal.Ref;
import com.squirrelparser.clause.terminal.Terminal;
import com.squirrelparser.parser.MatchResult;
import com.squirrelparser.parser.ParseResult;
import com.squirrelparser.parser.SyntaxError;

/**
 * Build an AST from a parse tree.
 */
public final class ASTBuilder {
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
