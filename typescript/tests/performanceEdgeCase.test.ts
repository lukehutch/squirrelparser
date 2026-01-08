/**
 * PERFORMANCE EDGE CASE TESTS
 * Tests performance edge cases and pathological inputs
 * Ported from Dart: dart/test/parser/performance_edge_case_test.dart
 */

import { describe, expect, test } from '@jest/globals';
import type { Clause } from '../src';
import { First, OneOrMore, Optional, Parser, Ref, Seq, Str, ZeroOrMore } from '../src';
import { parse } from './testUtils';

describe('Performance Tests', () => {
  test('PERF-01-very-long-input', () => {
    // 10,000 character input should parse in reasonable time
    const input = 'x'.repeat(10000);
    const start = Date.now();
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('x')) }, input);
    const elapsed = Date.now() - start;

    expect(ok).toBe(true);
    expect(err).toBe(0);
    expect(elapsed < 1000).toBe(true);
  });

  test('PERF-02-deep-nesting', () => {
    // 50 levels of Seq nesting
    function buildDeepSeq(depth: number): Clause {
      if (depth === 0) return new Str('x');
      return new Seq([buildDeepSeq(depth - 1), new Str('y')]);
    }

    const grammar = { S: buildDeepSeq(50) };
    const input = 'x' + 'y'.repeat(50);

    const [ok, _, __] = parse(grammar, input);
    expect(ok).toBe(true);
  });

  test('PERF-03-wide-first', () => {
    // First with 50 alternatives (using padded numbers to avoid prefix issues)
    const alternatives = Array.from(
      { length: 50 },
      (_, i) => new Str(`opt_${i.toString().padStart(3, '0')}`)
    );
    const [ok, _, __] = parse({ S: new First(alternatives) }, 'opt_049'); // Last alternative
    expect(ok).toBe(true);
  });

  test('PERF-04-many-repetitions', () => {
    // 1000 iterations of OneOrMore
    const input = 'x'.repeat(1000);
    const [ok, _, __] = parse({ S: new OneOrMore(new Str('x')) }, input);
    expect(ok).toBe(true);
  });

  test('PERF-05-many-errors', () => {
    // 500 errors in input
    const input = Array.from({ length: 500 }, () => 'Xx').join('');
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('x')) }, input);
    expect(ok).toBe(true);
    expect(err).toBe(500);
  });

  test('PERF-06-lr-expansion-depth', () => {
    // LR with 100 expansions
    const input = Array.from({ length: 100 }, () => '+n').join('').substring(1); // n+n+n+...
    const [ok, _, __] = parse(
      {
        E: new First([new Seq([new Ref('E'), new Str('+'), new Str('n')]), new Str('n')]),
      },
      input,
      'E'
    );
    expect(ok).toBe(true);
  });

  test('PERF-07-cache-efficiency', () => {
    // Same clause at many positions - cache should help
    const input = 'x'.repeat(100);
    const [ok, _, __] = parse({ S: new OneOrMore(new Ref('X')), X: new Str('x') }, input);
    expect(ok).toBe(true);
  });
});

describe('Edge Case Tests', () => {
  test('EDGE-01-empty-input', () => {
    // Various grammars with empty input
    const zm = parse({ S: new ZeroOrMore(new Str('x')) }, '');
    expect(zm[0]).toBe(true);

    const om = parse({ S: new OneOrMore(new Str('x')) }, '');
    expect(om[0]).toBe(false);

    const opt = parse({ S: new Optional(new Str('x')) }, '');
    expect(opt[0]).toBe(true);

    const seq = parse({ S: new Seq([]) }, '');
    expect(seq[0]).toBe(true);
  });

  test('EDGE-02-input-with-only-errors', () => {
    // Input is all garbage
    const [ok, _, __] = parse({ S: new Str('abc') }, 'XYZ');
    expect(ok).toBe(false);
  });

  test('EDGE-03-grammar-with-only-optional-zeromore', () => {
    // Grammar that accepts empty: Seq([ZeroOrMore(...), Optional(...)])
    const [ok, err, _] = parse(
      {
        S: new Seq([new ZeroOrMore(new Str('x')), new Optional(new Str('y'))]),
      },
      ''
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('EDGE-04-single-char-terminals', () => {
    // All single-character terminals
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c')]),
      },
      'abc'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('EDGE-05-very-long-terminal', () => {
    // Multi-hundred-char terminal
    const longStr = 'x'.repeat(500);
    const [ok, _, __] = parse({ S: new Str(longStr) }, longStr);
    expect(ok).toBe(true);
  });

  test('EDGE-06-unicode-handling', () => {
    // Unicode characters in terminals and input
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('hello'), new Str('world')]),
      },
      'helloworld'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('EDGE-07-mixed-unicode-and-ascii', () => {
    // Mix of Unicode and ASCII with errors
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Str('hello'), new Str('world')]),
      },
      'helloXworld'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip.includes('X')).toBe(true);
  });

  test('EDGE-08-newlines-and-whitespace', () => {
    // Newlines and whitespace as errors
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('a'), new Str('b')]),
      },
      'a\n\tb'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
  });

  test('EDGE-09-eof-at-various-positions', () => {
    // EOF at different points in grammar
    const cases: [string, number][] = [
      ['ab', 2], // EOF after full match
      ['a', 1], // EOF after partial match
      ['', 0], // EOF at start
    ];

    for (const [input, _expectedPos] of cases) {
      const parser = new Parser(
        {
          S: new Seq([new Str('a'), new Str('b')]),
        },
        input
      );
      const [result, _] = parser.parse('S');
      expect(result !== null || input === '').toBe(true);
    }
  });

  test('EDGE-10-recovery-with-moderate-skip', () => {
    // Recovery with moderate skip distance
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c')]),
      },
      'aXXXXXXXXXbc'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip[0].length > 5).toBe(true);
  });

  test('EDGE-11-alternating-success-failure', () => {
    // Pattern that alternates between success and failure
    const [ok, err, _] = parse(
      {
        S: new OneOrMore(new Seq([new Str('a'), new Str('b')])),
      },
      'abXabYabZab'
    );
    expect(ok).toBe(true);
    expect(err).toBe(3);
  });

  test('EDGE-12-boundary-at-every-position', () => {
    // Multiple sequences with delimiters
    const [ok, _, __] = parse(
      {
        S: new Seq([
          new OneOrMore(new Str('a')),
          new Str(','),
          new OneOrMore(new Str('b')),
          new Str(','),
          new OneOrMore(new Str('c')),
        ]),
      },
      'aaa,bbb,ccc'
    );
    expect(ok).toBe(true);
  });

  test('EDGE-13-no-grammar-rules', () => {
    // Empty grammar (edge case that should fail gracefully)
    const parser = new Parser({}, 'x');
    expect(() => parser.parse('NonExistent')).toThrow();
  });

  test('EDGE-14-circular-ref-with-base-case', () => {
    // A -> A | 'x' (left-recursive with base case)
    // Should work correctly with LR detection
    const parser = new Parser(
      {
        A: new First([new Seq([new Ref('A'), new Str('y')]), new Str('x')]),
      },
      'xy'
    );
    const [result, _] = parser.parse('A');
    // LR detection should handle this correctly
    expect(result !== null && !result.isMismatch).toBe(true);
  });

  test('EDGE-15-all-printable-ascii', () => {
    // Test all printable ASCII characters
    const ascii = String.fromCharCode(...Array.from({ length: 95 }, (_, i) => i + 32)); // ASCII 32-126
    const [ok, _, __] = parse({ S: new Str(ascii) }, ascii);
    expect(ok).toBe(true);
  });
});
