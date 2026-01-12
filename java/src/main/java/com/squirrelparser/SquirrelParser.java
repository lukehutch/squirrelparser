package com.squirrelparser;

import java.util.List;

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
     * <p>You must define a CSTNodeFactory to handle terminals, with the rule name '<Terminal>',
     * in order to construct CST nodes for terminal matches.
     *
     * <p>If allowSyntaxErrors is false, and a syntax error is encountered in the AST, an ArgumentError will be
     * thrown describing only the first syntax error encountered.
     *
     * <p>If allowSyntaxErrors is true, then you must define a CSTNodeFactory for the label '<SyntaxError>',
     * in order to decide how to construct CST nodes when there are syntax errors.
     *
     * @param grammarSpec      The grammar specification string
     * @param topRuleName      The top-level rule name to parse
     * @param factories        List of CST node factories
     * @param input            The input string to parse
     * @param allowSyntaxErrors Whether to allow syntax errors
     * @return The CST root node
     */
    public static CSTNodeBase squirrelParseCST(
            String grammarSpec,
            String topRuleName,
            List<CSTNodeFactory> factories,
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
