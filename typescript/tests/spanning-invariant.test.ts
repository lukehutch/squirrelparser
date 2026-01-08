/**
 * Parse Tree Spanning Invariant Tests
 *
 * These tests verify that Parser.parse() always returns a MatchResult
 * that completely spans the input (from position 0 to input.length).
 * - Total failures: SyntaxError spanning entire input
 * - Partial matches: wrapped with trailing SyntaxError
 * - Complete matches: result spans full input with no wrapper needed
 */

import {
  First,
  OneOrMore,
  Optional,
  Parser,
  Ref,
  Seq,
  Str,
  SyntaxError,
  ZeroOrMore,
  FollowedBy,
  NotFollowedBy,
  type Clause,
  type MatchResult,
} from '../src';

describe('Parse Tree Spanning Invariant Tests', () => {
  test('SPAN-01-empty-input', () => {
    const parser = new Parser({ S: new Str('a') }, '');
    const [result] = parser.parse('S');

    expect(result instanceof SyntaxError).toBe(true);
    expect(result.len).toBe(0);
    expect(result.pos).toBe(0);
  });

  test('SPAN-02-complete-match-no-wrapper', () => {
    const parser = new Parser(
      { S: new Seq([new Str('a'), new Str('b'), new Str('c')]) },
      'abc'
    );
    const [result] = parser.parse('S');

    expect(result instanceof SyntaxError).toBe(false);
    expect(result.isMismatch).toBe(false);
    expect(result.len).toBe(3);
  });

  test('SPAN-03-total-failure-returns-syntax-error', () => {
    const parser = new Parser({ S: new Str('a') }, 'xyz');
    const [result] = parser.parse('S');

    expect(result instanceof SyntaxError).toBe(true);
    expect(result.len).toBe(3);
    expect((result as SyntaxError).skipped).toBe('xyz');
  });

  test('SPAN-04-trailing-garbage-wrapped', () => {
    const parser = new Parser(
      { S: new Seq([new Str('a'), new Str('b')]) },
      'abXYZ'
    );
    const [result] = parser.parse('S');

    expect(result.len).toBe(5);
    expect(result instanceof SyntaxError).toBe(false);

    // Find the trailing SyntaxError in the tree
    let hasTrailingError = false;
    function checkForTrailingError(r: MatchResult): void {
      if (r instanceof SyntaxError && r.pos === 2 && r.len === 3) {
        hasTrailingError = true;
      }
      for (const child of r.subClauseMatches) {
        checkForTrailingError(child);
      }
    }

    checkForTrailingError(result);
    expect(hasTrailingError).toBe(true);
  });

  test('SPAN-05-single-char-trailing', () => {
    const parser = new Parser({ S: new Str('a') }, 'aX');
    const [result] = parser.parse('S');

    expect(result.len).toBe(2);
    expect(result instanceof SyntaxError).toBe(false);

    let hasTrailingError = false;
    function checkForTrailingError(r: MatchResult): void {
      if (r instanceof SyntaxError && r.pos === 1 && r.len === 1) {
        hasTrailingError = true;
      }
      for (const child of r.subClauseMatches) {
        checkForTrailingError(child);
      }
    }

    checkForTrailingError(result);
    expect(hasTrailingError).toBe(true);
  });

  test('SPAN-06-multiple-errors-throughout', () => {
    const parser = new Parser(
      { S: new Seq([new Str('a'), new Str('b'), new Str('c')]) },
      'aXbYc'
    );
    const [result] = parser.parse('S');

    expect(result.len).toBe(5);

    const errors: SyntaxError[] = [];
    function collectErrors(r: MatchResult): void {
      if (r instanceof SyntaxError) {
        errors.push(r);
      }
      for (const child of r.subClauseMatches) {
        collectErrors(child);
      }
    }

    collectErrors(result);
    expect(errors.length).toBe(2);
  });

  test('SPAN-07-recovery-with-deletion', () => {
    const parser = new Parser(
      { S: new Seq([new Str('a'), new Str('b'), new Str('c')]) },
      'ab'
    );
    const [result] = parser.parse('S');

    expect(result.len).toBe(2);
    expect(result instanceof SyntaxError).toBe(false);
  });

  test('SPAN-08-first-alternative-with-trailing', () => {
    const parser = new Parser(
      {
        S: new First([
          new Seq([new Str('a'), new Str('b'), new Str('c')]),
          new Str('a'),
        ]),
      },
      'abcX'
    );
    const [result] = parser.parse('S');

    expect(result.len).toBe(4);

    let hasTrailingX = false;
    function checkForX(r: MatchResult): void {
      if (r instanceof SyntaxError && r.skipped.includes('X')) {
        hasTrailingX = true;
      }
      for (const child of r.subClauseMatches) {
        checkForX(child);
      }
    }

    checkForX(result);
    expect(hasTrailingX).toBe(true);
  });

  test('SPAN-09-left-recursion-with-trailing', () => {
    const parser = new Parser(
      {
        E: new First([
          new Seq([new Ref('E'), new Str('+'), new Str('n')]),
          new Str('n'),
        ]),
      },
      'n+nX'
    );
    const [result] = parser.parse('E');

    expect(result.len).toBe(4);

    let hasTrailingError = false;
    function checkForTrailingError(r: MatchResult): void {
      if (r instanceof SyntaxError && r.pos > 0) {
        hasTrailingError = true;
      }
      for (const child of r.subClauseMatches) {
        checkForTrailingError(child);
      }
    }

    checkForTrailingError(result);
    expect(hasTrailingError).toBe(true);
  });

  test('SPAN-10-repetition-with-trailing', () => {
    const parser = new Parser({ S: new OneOrMore(new Str('a')) }, 'aaaX');
    const [result] = parser.parse('S');

    expect(result.len).toBe(4);

    let hasTrailingError = false;
    function checkForTrailingError(r: MatchResult): void {
      if (r instanceof SyntaxError && r.skipped.includes('X')) {
        hasTrailingError = true;
      }
      for (const child of r.subClauseMatches) {
        checkForTrailingError(child);
      }
    }

    checkForTrailingError(result);
    expect(hasTrailingError).toBe(true);
  });

  test('SPAN-11-nested-rules-with-trailing', () => {
    const parser = new Parser(
      {
        S: new Seq([new Ref('A'), new Str(';')]),
        A: new Seq([new Str('a'), new Str('b')]),
      },
      'ab;X'
    );
    const [result] = parser.parse('S');

    expect(result.len).toBe(4);
  });

  test('SPAN-12-zero-or-more-with-trailing', () => {
    const parser = new Parser({ S: new ZeroOrMore(new Str('a')) }, 'XYZ');
    const [result] = parser.parse('S');

    expect(result.len).toBe(3);
    expect(result instanceof SyntaxError).toBe(false);

    let hasTrailingError = false;
    function checkForTrailingError(r: MatchResult): void {
      if (r instanceof SyntaxError) {
        hasTrailingError = true;
      }
      for (const child of r.subClauseMatches) {
        checkForTrailingError(child);
      }
    }

    checkForTrailingError(result);
    expect(hasTrailingError).toBe(true);
  });

  test('SPAN-13-optional-with-trailing', () => {
    const parser = new Parser({ S: new Optional(new Str('a')) }, 'XYZ');
    const [result] = parser.parse('S');

    expect(result.len).toBe(3);

    let hasTrailingError = false;
    function checkForTrailingError(r: MatchResult): void {
      if (r instanceof SyntaxError) {
        hasTrailingError = true;
      }
      for (const child of r.subClauseMatches) {
        checkForTrailingError(child);
      }
    }

    checkForTrailingError(result);
    expect(hasTrailingError).toBe(true);
  });

  test('SPAN-14-followed-by-success-with-trailing', () => {
    const parser = new Parser(
      {
        S: new Seq([new FollowedBy(new Str('a')), new Str('a'), new Str('b')]),
      },
      'abX'
    );
    const [result] = parser.parse('S');

    expect(result.len).toBe(3);

    let hasTrailingError = false;
    function checkForTrailingError(r: MatchResult): void {
      if (r instanceof SyntaxError && r.skipped.includes('X')) {
        hasTrailingError = true;
      }
      for (const child of r.subClauseMatches) {
        checkForTrailingError(child);
      }
    }

    checkForTrailingError(result);
    expect(hasTrailingError).toBe(true);
  });

  test('SPAN-15-not-followed-by-failure-total', () => {
    const parser = new Parser(
      {
        S: new Seq([new NotFollowedBy(new Str('x')), new Str('y')]),
      },
      'xz'
    );
    const [result] = parser.parse('S');

    expect(result instanceof SyntaxError).toBe(true);
    expect(result.len).toBe(2);
  });

  test('SPAN-16-optional-with-trailing-simple', () => {
    const parser = new Parser(
      {
        S: new Seq([new Str('b'), new Optional(new Str('c'))]),
      },
      'bX'
    );
    const [result] = parser.parse('S');

    expect(result.len).toBe(2);

    let hasTrailingError = false;
    function checkForTrailingError(r: MatchResult): void {
      if (r instanceof SyntaxError && r.skipped.includes('X')) {
        hasTrailingError = true;
      }
      for (const child of r.subClauseMatches) {
        checkForTrailingError(child);
      }
    }

    checkForTrailingError(result);
    expect(hasTrailingError).toBe(true);
  });

  test('SPAN-17-invariant-never-null', () => {
    const testCases: Array<[Record<string, Clause>, string]> = [
      [{ S: new Str('a') }, 'a'],
      [{ S: new Str('a') }, 'b'],
      [{ S: new Str('a') }, ''],
      [{ S: new Seq([new Str('a'), new Str('b')]) }, 'ab'],
      [{ S: new Seq([new Str('a'), new Str('b')]) }, 'aXb'],
      [{ S: new First([new Str('a'), new Str('b')]) }, 'c'],
    ];

    for (const [rules, input] of testCases) {
      const parser = new Parser(rules, input);
      const [result] = parser.parse('S');

      expect(result).not.toBeNull();
      expect(result.len).toBe(input.length);
    }
  });

  test('SPAN-18-long-input-with-single-trailing-error', () => {
    const chars = 'abcdefghijklmnopqrstuvwxyz'.split('');
    const input = 'abcdefghijklmnopqrstuvwxyzX';
    const parser = new Parser(
      { S: new Seq(chars.map((c) => new Str(c))) },
      input
    );
    const [result] = parser.parse('S');

    expect(result.len).toBe(27);

    let hasTrailingError = false;
    function checkForTrailingError(r: MatchResult): void {
      if (r instanceof SyntaxError && r.pos === 26) {
        hasTrailingError = true;
      }
      for (const child of r.subClauseMatches) {
        checkForTrailingError(child);
      }
    }

    checkForTrailingError(result);
    expect(hasTrailingError).toBe(true);
  });

  test('SPAN-19-complex-grammar-with-errors', () => {
    const parser = new Parser(
      {
        S: new Seq([new Ref('E'), new Str(';')]),
        E: new First([
          new Seq([new Ref('E'), new Str('+'), new Ref('T')]),
          new Ref('T'),
        ]),
        T: new Str('n'),
      },
      'n+Xn;Y'
    );
    const [result] = parser.parse('S');

    expect(result.len).toBe(6);

    const errors: SyntaxError[] = [];
    function collectErrors(r: MatchResult): void {
      if (r instanceof SyntaxError) {
        errors.push(r);
      }
      for (const child of r.subClauseMatches) {
        collectErrors(child);
      }
    }

    collectErrors(result);
    expect(errors.length).toBeGreaterThanOrEqual(2);
  });

  test('SPAN-20-recovery-preserves-matched-content', () => {
    const parser = new Parser(
      {
        S: new Seq([new Str('hello'), new Str(' '), new Str('world')]),
      },
      'hello X world'
    );
    const [result] = parser.parse('S');

    expect(result.len).toBe(13);
    expect(result instanceof SyntaxError).toBe(false);

    let hasError = false;
    function analyze(r: MatchResult): void {
      if (r instanceof SyntaxError) {
        hasError = true;
      }
      for (const child of r.subClauseMatches) {
        analyze(child);
      }
    }

    analyze(result);
    expect(hasError).toBe(true);
  });
});
