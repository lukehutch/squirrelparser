import { Clause } from './clause.js';
import { Match, mismatch, type MatchResult } from './matchResult.js';
import type { Parser } from './parser.js';
import { escapeString } from './utils.js';

// -----------------------------------------------------------------------------------------------------------------

/**
 * Abstract base class for terminal clauses.
 */
export abstract class Terminal extends Clause {
  /** The AST/CST node label for terminals. */
  static readonly nodeLabel = '<Terminal>';

  checkRuleRefs(_grammarMap: Map<string, Clause>): void {
    // Terminals have no references to check.
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Matches a literal string.
 */
export class Str extends Terminal {
  readonly text: string;

  constructor(text: string) {
    super();
    this.text = text;
  }

  match(parser: Parser, pos: number, _bound?: Clause): MatchResult {
    if (pos + this.text.length > parser.input.length) return mismatch;
    for (let i = 0; i < this.text.length; i++) {
      if (parser.input.charCodeAt(pos + i) !== this.text.charCodeAt(i)) {
        return mismatch;
      }
    }
    return new Match(this, pos, this.text.length);
  }

  toString(): string {
    return `"${escapeString(this.text)}"`;
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Matches a single character.
 */
export class Char extends Terminal {
  readonly char: string;

  constructor(char: string) {
    super();
    if (char.length !== 1) {
      throw new Error('Char must be a single character');
    }
    this.char = char;
  }

  match(parser: Parser, pos: number, _bound?: Clause): MatchResult {
    if (pos + this.char.length > parser.input.length) return mismatch;
    for (let i = 0; i < this.char.length; i++) {
      if (parser.input.charCodeAt(pos + i) !== this.char.charCodeAt(i)) {
        return mismatch;
      }
    }
    return new Match(this, pos, this.char.length);
  }

  toString(): string {
    return `'${escapeString(this.char)}'`;
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Matches a single character in a set of character ranges.
 *
 * Supports multiple ranges and an optional inversion flag for negated character
 * classes like `[^a-zA-Z0-9]`.
 */
export class CharSet extends Terminal {
  /** List of character ranges as [lo, hi] code unit pairs (inclusive). */
  readonly ranges: ReadonlyArray<readonly [number, number]>;

  /** If true, matches any character NOT in the set. */
  readonly inverted: boolean;

  constructor(ranges: ReadonlyArray<readonly [number, number]>, inverted: boolean = false) {
    super();
    this.ranges = ranges;
    this.inverted = inverted;
  }

  /** Convenience factory for a single character range. */
  static range(lo: string, hi: string): CharSet {
    return new CharSet([[lo.charCodeAt(0), hi.charCodeAt(0)]], false);
  }

  /** Convenience factory for a single character. */
  static char(c: string): CharSet {
    const cp = c.charCodeAt(0);
    return new CharSet([[cp, cp]], false);
  }

  /** Convenience factory for a negated single character range. */
  static notRange(lo: string, hi: string): CharSet {
    return new CharSet([[lo.charCodeAt(0), hi.charCodeAt(0)]], true);
  }

  match(parser: Parser, pos: number, _bound?: Clause): MatchResult {
    if (pos >= parser.input.length) return mismatch;
    const c = parser.input.charCodeAt(pos);

    let inSet = false;
    for (const [lo, hi] of this.ranges) {
      if (c >= lo && c <= hi) {
        inSet = true;
        break;
      }
    }

    if (this.inverted ? !inSet : inSet) {
      return new Match(this, pos, 1);
    }
    return mismatch;
  }

  toString(): string {
    const parts: string[] = ['['];
    if (this.inverted) parts.push('^');
    for (const [lo, hi] of this.ranges) {
      if (lo === hi) {
        parts.push(escapeString(String.fromCharCode(lo)));
      } else {
        parts.push(escapeString(String.fromCharCode(lo)));
        parts.push('-');
        parts.push(escapeString(String.fromCharCode(hi)));
      }
    }
    parts.push(']');
    return parts.join('');
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Matches any single character.
 */
export class AnyChar extends Terminal {
  match(parser: Parser, pos: number, _bound?: Clause): MatchResult {
    if (pos >= parser.input.length) return mismatch;
    return new Match(this, pos, 1);
  }

  toString(): string {
    return '.';
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Matches nothing - always succeeds without consuming any input.
 */
export class Nothing extends Terminal {
  match(_parser: Parser, pos: number, _bound?: Clause): MatchResult {
    return new Match(this, pos, 0);
  }

  toString(): string {
    return '()';
  }
}
