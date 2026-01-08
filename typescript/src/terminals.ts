/**
 * Terminal clause implementations for the Squirrel Parser.
 */

import type { Clause } from './clause';
import type { Parser } from './parser';
import type { MatchResult } from './matchResult';
import { Match, MISMATCH } from './matchResult';

/**
 * Matches a literal string.
 */
export class Str implements Clause {
  readonly transparent = false;

  constructor(readonly text: string) {}

  match(parser: Parser, pos: number, _bound: Clause | null): MatchResult {
    if (pos + this.text.length > parser.input.length) {
      return MISMATCH;
    }
    for (let i = 0; i < this.text.length; i++) {
      if (parser.input[pos + i] !== this.text[i]) {
        return MISMATCH;
      }
    }
    return new Match(this, pos, this.text.length);
  }

  toString(): string {
    return `"${this.text}"`;
  }
}

/**
 * Matches a single character.
 */
export class Char implements Clause {
  readonly transparent = false;

  constructor(readonly char: string) {
    if (char.length !== 1) {
      throw new Error('Char must be exactly one character');
    }
  }

  match(parser: Parser, pos: number, _bound: Clause | null): MatchResult {
    if (pos >= parser.input.length) {
      return MISMATCH;
    }
    if (parser.input[pos] === this.char) {
      return new Match(this, pos, 1);
    }
    return MISMATCH;
  }

  toString(): string {
    return `'${this.char}'`;
  }
}

/**
 * Matches a single character in a range [lo-hi].
 */
export class CharRange implements Clause {
  readonly transparent = false;

  constructor(readonly lo: string, readonly hi: string) {
    if (lo.length !== 1 || hi.length !== 1) {
      throw new Error('CharRange bounds must be single characters');
    }
  }

  match(parser: Parser, pos: number, _bound: Clause | null): MatchResult {
    if (pos >= parser.input.length) {
      return MISMATCH;
    }
    const ch = parser.input[pos];
    if (this.lo <= ch && ch <= this.hi) {
      return new Match(this, pos, 1);
    }
    return MISMATCH;
  }

  toString(): string {
    return `[${this.lo}-${this.hi}]`;
  }
}

/**
 * Matches any single character.
 */
export class AnyChar implements Clause {
  readonly transparent = false;

  match(parser: Parser, pos: number, _bound: Clause | null): MatchResult {
    if (pos >= parser.input.length) {
      return MISMATCH;
    }
    return new Match(this, pos, 1);
  }

  toString(): string {
    return '.';
  }
}
