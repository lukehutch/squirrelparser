/**
 * Public Squirrel Parser API.
 */

import { ASTNode, buildAST, buildCST, CSTNode, CSTNodeFactoryFn } from './cstNode.js';
import { MetaGrammar } from './metaGrammar.js';
import { Parser, ParseResult } from './parser.js';

// -----------------------------------------------------------------------------------------------------------------

/**
 * Parse input and return a Concrete Syntax Tree (CST).
 *
 * Internally, the Abstract Syntax Tree (AST) is built from the parse tree, eliding all nodes that are
 * not rule references or terminals. (Transparent rule refs are elided too.)
 *
 * The CST is then constructed from the Abstract Syntax Tree (AST) using the provided factory functions.
 * This allows for fully custom syntax tree representations. You can decide whether to include, process,
 * ignore, or transform any child nodes when your factory methods construct CST nodes from the AST.
 *
 * You must define a CSTNodeFactory to handle terminals, with the rule name '<Terminal>',
 * in order to construct CST nodes for terminal matches.
 *
 * If allowSyntaxErrors is false, and a syntax error is encountered in the AST, an ArgumentError will be
 * thrown describing only the first syntax error encountered.
 *
 * If allowSyntaxErrors is true, then you must define a CSTNodeFactory for the label '<SyntaxError>',
 * in order to decide how to construct CST nodes when there are syntax errors.
 */
export function squirrelParseCST(options: {
  grammarSpec: string;
  topRuleName: string;
  factories: Map<string, CSTNodeFactoryFn>;
  input: string;
  allowSyntaxErrors?: boolean;
}): CSTNode {
  return buildCST(
    squirrelParseAST({
      grammarSpec: options.grammarSpec,
      topRuleName: options.topRuleName,
      input: options.input,
    }),
    options.factories,
    options.allowSyntaxErrors ?? false
  );
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Call the Squirrel Parser with the given grammar, top rule, and input, and return the
 * Abstract Syntax Tree (AST), which consists of only non-transparent rule references and terminals.
 * Non-rule-ref AST nodes will have the label '<Terminal>' for terminals and '<SyntaxError>'
 * for syntax errors.
 */
export function squirrelParseAST(options: {
  grammarSpec: string;
  topRuleName: string;
  input: string;
}): ASTNode {
  return buildAST(
    squirrelParsePT({
      grammarSpec: options.grammarSpec,
      topRuleName: options.topRuleName,
      input: options.input,
    })
  );
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Call the Squirrel Parser with the given grammar, top rule, and input, and return the raw parse tree (PT).
 * This is the lowest-level parsing function.
 */
export function squirrelParsePT(options: {
  grammarSpec: string;
  topRuleName: string;
  input: string;
}): ParseResult {
  return new Parser({
    rules: MetaGrammar.parseGrammar(options.grammarSpec),
    topRuleName: options.topRuleName,
    input: options.input,
  }).parse();
}
