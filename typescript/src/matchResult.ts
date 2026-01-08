/**
 * Match result types for the Squirrel Parser.
 */

import type { Clause } from './clause';

/**
 * Base interface for all match results.
 */
export interface MatchResult {
  readonly clause: Clause | null;
  readonly pos: number;
  readonly len: number;
  readonly isComplete: boolean;
  readonly isFromLRContext: boolean;
  readonly subClauseMatches: readonly MatchResult[];
  readonly isMismatch: boolean;
  withLRContext(): MatchResult;
  toPrettyString(input: string, indent?: number): string;
}

/**
 * Successful match result.
 */
export class Match implements MatchResult {
  readonly clause: Clause | null;
  readonly pos: number;
  readonly len: number;
  readonly subClauseMatches: readonly MatchResult[];
  readonly isComplete: boolean;
  readonly isFromLRContext: boolean;
  readonly isMismatch = false;

  constructor(
    clause: Clause | null,
    pos: number,
    len: number,
    subClauseMatches: readonly MatchResult[] = [],
    isComplete: boolean = true,
    isFromLRContext?: boolean
  ) {
    this.clause = clause;
    this.subClauseMatches = subClauseMatches;
    this.isComplete = isComplete;

    // Auto-compute pos and len from children if provided
    if (subClauseMatches.length > 0) {
      this.pos = subClauseMatches[0].pos;
      const last = subClauseMatches[subClauseMatches.length - 1];
      this.len = last.pos + last.len - this.pos;

      // Auto-compute isFromLRContext if not explicitly set
      if (isFromLRContext === undefined || isFromLRContext === null) {
        this.isFromLRContext = subClauseMatches.some(r => r.isFromLRContext);
      } else {
        this.isFromLRContext = isFromLRContext;
      }
    } else {
      this.pos = pos;
      this.len = len;
      this.isFromLRContext = isFromLRContext ?? false;
    }
  }

  withLRContext(): MatchResult {
    if (this.isFromLRContext) {
      return this;
    }
    return new Match(
      this.clause,
      this.pos,
      this.len,
      this.subClauseMatches,
      this.isComplete,
      true
    );
  }

  toPrettyString(input: string, indent: number = 0): string {
    const prefix = '  '.repeat(indent);
    const clauseName = this.clause && 'name' in this.clause
      ? (this.clause as { name: string }).name
      : this.clause?.constructor.name || 'Unknown';

    let result = `${prefix}${clauseName}`;

    if (this.subClauseMatches.length === 0) {
      result += `: "${input.substring(this.pos, this.pos + this.len)}"`;
    }

    result += '\n';

    for (const child of this.subClauseMatches) {
      result += child.toPrettyString(input, indent + 1);
    }

    return result;
  }
}

/**
 * Mismatch result (sentinel with len=-1).
 */
export class Mismatch implements MatchResult {
  readonly clause = null;
  readonly pos = -1;
  readonly len = -1;
  readonly isComplete = true;
  readonly subClauseMatches: readonly MatchResult[] = [];
  readonly isMismatch = true;

  constructor(readonly isFromLRContext: boolean = false) {}

  withLRContext(): MatchResult {
    return LR_PENDING;
  }

  toPrettyString(input: string, indent: number = 0): string {
    return `${'  '.repeat(indent)}MISMATCH\n`;
  }
}

/**
 * Syntax error node: records skipped input or deleted grammar elements.
 */
export class SyntaxError implements MatchResult {
  readonly clause = null;
  readonly isComplete = true;
  readonly isFromLRContext = false;
  readonly subClauseMatches: readonly MatchResult[] = [];
  readonly isMismatch = false;

  constructor(
    readonly pos: number,
    readonly len: number,
    readonly skipped: string = '',
    readonly isDeletion: boolean = false
  ) {}

  withLRContext(): MatchResult {
    return this;
  }

  toString(): string {
    if (this.isDeletion) {
      return `DELETION@${this.pos}`;
    }
    return `SKIP("${this.skipped}")@${this.pos}`;
  }

  toPrettyString(input: string, indent: number = 0): string {
    return `${'  '.repeat(indent)}${this.toString()}\n`;
  }
}

// Singleton instances
export const MISMATCH = new Mismatch();
export const LR_PENDING = new Mismatch(true);
