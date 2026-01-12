import type { MatchResult } from './matchResult.js';
import type { Parser } from './parser.js';

// -----------------------------------------------------------------------------------------------------------------

/**
 * Base class for all grammar clauses.
 */
export abstract class Clause {
  /**
   * Match this clause at the given position.
   */
  abstract match(parser: Parser, pos: number, bound?: Clause): MatchResult;

  /**
   * Check that all rule references in this clause are valid.
   */
  abstract checkRuleRefs(grammarMap: Map<string, Clause>): void;

  toString(): string {
    return this.constructor.name;
  }
}
