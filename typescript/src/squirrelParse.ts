/**
 * squirrelParse convenience function - parses input and returns both AST and syntax errors.
 * Defined in separate file to avoid circular dependency with ast module.
 */

import type { Clause } from './clause';
import { Parser } from './parser';
import { buildAST, ASTNode } from './ast';
import { getSyntaxErrors } from './combinators';
import type { SyntaxError } from './matchResult';

/**
 * Convenience function to parse input and return both AST and syntax errors.
 *
 * @param rules The grammar rules map
 * @param topRule The name of the top-level rule to parse
 * @param input The input string to parse
 * @returns A tuple [ast, syntaxErrors] where ast is always non-null (possibly empty)
 */
export function squirrelParse(
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
