/**
 * Base clause interface for the Squirrel Parser.
 */

import type { MatchResult } from './matchResult';
import type { Parser } from './parser';

/**
 * Protocol for all grammar clauses.
 */
export interface Clause {
  /**
   * If true, this clause is transparent in the AST - its children are promoted
   * to the parent rather than creating a node for this clause.
   */
  readonly transparent: boolean;

  /**
   * Match this clause at the given position in the parser's input.
   *
   * @param parser - The parser instance
   * @param pos - The position to match at
   * @param bound - Optional boundary clause for recovery
   * @returns Match result (Match, Mismatch, or SyntaxError)
   */
  match(parser: Parser, pos: number, bound: Clause | null): MatchResult;
}
