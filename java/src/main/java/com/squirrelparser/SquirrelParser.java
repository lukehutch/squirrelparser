package com.squirrelparser;

import java.util.Map;

import com.squirrelparser.parser.MetaGrammar;
import com.squirrelparser.parser.ParseResult;
import com.squirrelparser.parser.Parser;
import com.squirrelparser.tree.ASTBuilder;
import com.squirrelparser.tree.ASTNode;
import com.squirrelparser.tree.CSTBuilder;
import com.squirrelparser.tree.CSTNode;
import com.squirrelparser.tree.CSTNodeFactoryFn;

/**
 * Public Squirrel Parser API.
 */
public final class SquirrelParser {
    private SquirrelParser() {}

    /**
     * Parse input and return a Concrete Syntax Tree (CST).
     *
     * <p>Internally, the Abstract Syntax Tree (AST) is built from the parse tree, eliding all nodes that are
     * not rule references or terminals. (Transparent rule refs are elided too.)
     *
     * <p>The CST is then constructed from the Abstract Syntax Tree (AST) using the provided factory functions.
     * This allows for fully custom syntax tree representations. You can decide whether to include, process,
     * ignore, or transform any child nodes when your factory methods construct CST nodes from the AST.
     *
     * <p>The factories map should contain an entry for each rule name in the grammar, plus:
     * <ul>
     *   <li>'&lt;Terminal&gt;' for terminal matches (string literals, character classes, etc.)</li>
     *   <li>'&lt;SyntaxError&gt;' if allowSyntaxErrors is true</li>
     * </ul>
     *
     * <p>If allowSyntaxErrors is false, and a syntax error is encountered in the AST, an ArgumentError will be
     * thrown describing only the first syntax error encountered.
     *
     * <p>If allowSyntaxErrors is true, then you must define a factory for the label '&lt;SyntaxError&gt;',
     * in order to decide how to construct CST nodes when there are syntax errors.
     *
     * @param grammarSpec      The grammar specification string
     * @param topRuleName      The top-level rule name to parse
     * @param factories        Map from rule name to CST node factory function
     * @param input            The input string to parse
     * @param allowSyntaxErrors Whether to allow syntax errors
     * @return The CST root node
     */
    public static CSTNode squirrelParseCST(
            String grammarSpec,
            String topRuleName,
            Map<String, CSTNodeFactoryFn> factories,
            String input,
            boolean allowSyntaxErrors) {
        return CSTBuilder.buildCST(
            squirrelParseAST(grammarSpec, topRuleName, input),
            factories,
            allowSyntaxErrors
        );
    }

    /**
     * Call the Squirrel Parser with the given grammar, top rule, and input, and return the
     * Abstract Syntax Tree (AST), which consists of only non-transparent rule references and terminals.
     * Non-rule-ref AST nodes will have the label '<Terminal>' for terminals and '<SyntaxError>'
     * for syntax errors.
     *
     * @param grammarSpec The grammar specification string
     * @param topRuleName The top-level rule name to parse
     * @param input       The input string to parse
     * @return The AST root node
     */
    public static ASTNode squirrelParseAST(String grammarSpec, String topRuleName, String input) {
        return ASTBuilder.buildAST(squirrelParsePT(grammarSpec, topRuleName, input));
    }

    /**
     * Call the Squirrel Parser with the given grammar, top rule, and input, and return the raw parse tree (PT).
     * This is the lowest-level parsing function.
     *
     * @param grammarSpec The grammar specification string
     * @param topRuleName The top-level rule name to parse
     * @param input       The input string to parse
     * @return The parse result
     */
    public static ParseResult squirrelParsePT(String grammarSpec, String topRuleName, String input) {
        return new Parser(MetaGrammar.parseGrammar(grammarSpec), topRuleName, input).parse();
    }
}
