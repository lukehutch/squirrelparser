/**
 * squirrelParse convenience function - parses input and returns both AST and syntax errors.
 * Defined in separate file to avoid circular dependency with ast module.
 */

import type { Clause } from './clause';
import { Parser } from './parser';
import { buildAST, ASTNode } from './ast';
import { getSyntaxErrors } from './combinators';
import type { SyntaxError } from './matchResult';
import { MetaGrammar } from './metaGrammar';

/**
 * Convenience function to parse input and return both AST and syntax errors.
 *
 * @param grammarStr The grammar as a PEG metagrammar string
 * @param input The input string to parse
 * @param topRule The name of the top-level rule to parse
 * @returns A tuple [ast, syntaxErrors] where ast is always non-null (possibly empty)
 */
export function squirrelParse(
  grammarStr: string,
  input: string,
  topRule: string
): [ASTNode, SyntaxError[]] {
  const parsedRules = MetaGrammar.parseGrammar(grammarStr);
  return squirrelParseInternal(parsedRules, topRule, input);
}

/**
 * Convenience function to parse input and return both AST and syntax errors.
 *
 * @param rules The grammar rules map
 * @param topRule The name of the top-level rule to parse
 * @param input The input string to parse
 * @returns A tuple [ast, syntaxErrors] where ast is always non-null (possibly empty)
 */
export function squirrelParseWithRuleMap(
  rules: Record<string, Clause>,
  topRule: string,
  input: string
): [ASTNode, SyntaxError[]] {
  return squirrelParseInternal(rules, topRule, input);
}

/**
 * Internal implementation shared by public methods.
 */
function squirrelParseInternal(
  rules: Record<string, Clause>,
  topRule: string,
  input: string
): [ASTNode, SyntaxError[]] {
  const parser = new Parser(rules, input);
  const [matchResult, _] = parser.parse(topRule);

  const ast = buildAST(matchResult, input, topRule) ?? new ASTNode(topRule, matchResult.pos, matchResult.len, [], input);
  const syntaxErrors = getSyntaxErrors(matchResult, input);

  return [ast, syntaxErrors];
}
