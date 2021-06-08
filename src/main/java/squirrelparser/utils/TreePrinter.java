//
// This file is part of the pika parser reference implementation:
//
//     https://github.com/lukehutch/pikaparser
//
// The pika parsing algorithm is described in the following paper: 
//
//     Pika parsing: reformulating packrat parsing as a dynamic programming algorithm solves the left recursion
//     and error recovery problems. Luke A. D. Hutchison, May 2020.
//     https://arxiv.org/abs/2005.06444
//
// This software is provided under the MIT license:
//
// Copyright 2020 Luke A. D. Hutchison
//  
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions
// of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
// TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//
package squirrelparser.utils;

import squirrelparser.node.ASTNode;
import squirrelparser.node.Match;

/** Methods for converting a tree structure into ASCII art form. */
public class TreePrinter {
    /** Render the AST rooted at an {@link ASTNode} into a StringBuffer. */
    public static void renderTreeView(ASTNode astNode, String indentStr, boolean isLastChild, StringBuilder buf) {
        int maxTextLen = 80;
        String text = astNode.getText();
        if (text.length() > maxTextLen) {
            text = text.substring(0, maxTextLen) + "...";
        }
        text = StringUtils.escapeString(text);

        // Uncomment for double-spaced rows
        // buf.append(indentStr + "│\n");

        buf.append(indentStr + (isLastChild ? "└─" : "├─") + astNode.label + " : " + astNode.pos + "+" + astNode.len
                + " : \"" + text + "\"\n");
        if (astNode.children != null) {
            for (int i = 0; i < astNode.children.size(); i++) {
                renderTreeView(astNode.children.get(i), indentStr + (isLastChild ? "  " : "│ "),
                        i == astNode.children.size() - 1, buf);
            }
        }
    }

    /** Render a parse tree rooted at a {@link Match} node into a StringBuffer. */
    public static void renderTreeView(Match match, String astNodeLabel, String input, String indentStr,
            boolean isLastChild, StringBuilder buf) {
        int inpLen = 80;
        String inp = input.substring(match.pos, Math.min(input.length(), match.pos + Math.min(match.len, inpLen)));
        if (inp.length() == inpLen) {
            inp += "...";
        }
        inp = StringUtils.escapeString(inp);

        // Uncomment for double-spaced rows
        // buf.append(indentStr + "│\n");

        buf.append(indentStr);
        buf.append(isLastChild ? "└─" : "├─");
        if (match.clause.rule != null) {
            buf.append(match.clause.rule.ruleName + " <- ");
        }
        buf.append(match.clause);
        buf.append(" : ");
        buf.append(match.pos);
        buf.append('+');
        buf.append(match.len);
        buf.append(" : \"");
        buf.append(inp);
        buf.append("\"\n");

        // Recurse to descendants
        var subClauseMatches = match.subClauseMatches;
        for (int subClauseMatchIdx = 0; subClauseMatchIdx < subClauseMatches.size(); subClauseMatchIdx++) {
            var subClauseMatch = subClauseMatches.get(subClauseMatchIdx);
            var subClauseASTNodeLabel = subClauseMatch.clause.astNodeLabel;
            renderTreeView(subClauseMatch, subClauseASTNodeLabel, input, indentStr + (isLastChild ? "  " : "│ "),
                    subClauseMatchIdx == subClauseMatches.size() - 1, buf);
        }
    }

    /** Print the parse tree rooted at a {@link Match} node to stdout. */
    public void printTreeView(Match match, String input) {
        var buf = new StringBuilder();
        renderTreeView(match, null, input, "", true, buf);
        System.out.println(buf.toString());
    }
}
