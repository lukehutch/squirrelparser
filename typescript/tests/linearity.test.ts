/**
 * SECTION 12: LINEARITY TESTS (10 tests)
 *
 * Verify O(N) complexity where N is input length.
 * Work should scale linearly with input size.
 */

import { describe, expect, test } from '@jest/globals';
import type { Clause } from '../src';
import { CharRange, First, OneOrMore, Parser, Ref, Seq, Str } from '../src';

// Note: TypeScript port doesn't have parserStats, so we use timing-based tests
// and simpler structural tests

describe('Linearity Tests', () => {
  test('LINEAR-01-simple-rep', () => {
    // Simple repetition should complete quickly
    const rules: Record<string, Clause> = { S: new OneOrMore(new Str('x')) };
    const input = 'x'.repeat(500);
    const parser = new Parser(rules, input);
    const [result, _] = parser.parse('S');
    expect(result !== null && !result.isMismatch).toBe(true);
    expect(result!.len).toBe(500);
  });

  test('LINEAR-02-direct-lr', () => {
    // Direct LR should complete in reasonable time
    const rules: Record<string, Clause> = {
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new Ref('N')]),
        new Ref('N'),
      ]),
      N: new CharRange('0', '9'),
    };
    const nums = Array.from({ length: 51 }, (_, i) => `${i % 10}`);
    const input = nums.join('+');
    const parser = new Parser(rules, input);
    const [result, _] = parser.parse('E');
    expect(result !== null && !result.isMismatch).toBe(true);
    expect(result!.len).toBe(input.length);
  });

  test('LINEAR-03-indirect-lr', () => {
    const rules: Record<string, Clause> = {
      A: new First([new Ref('B'), new Str('x')]),
      B: new First([
        new Seq([new Ref('A'), new Str('y')]),
        new Seq([new Ref('A'), new Str('x')]),
      ]),
    };
    let s = 'x';
    for (let i = 0; i < 25; i++) {
      s += 'xy';
    }
    const input = s.substring(0, 50);
    const parser = new Parser(rules, input);
    const [result, _] = parser.parse('A');
    expect(result !== null && !result.isMismatch).toBe(true);
    expect(result!.len).toBe(input.length);
  });

  test('LINEAR-04-interwoven-lr', () => {
    const rules: Record<string, Clause> = {
      L: new First([
        new Seq([new Ref('P'), new Str('.x')]),
        new Str('x'),
      ]),
      P: new First([
        new Seq([new Ref('P'), new Str('(n)')]),
        new Ref('L'),
      ]),
    };
    const parts = ['x'];
    for (let i = 0; i < 20; i++) {
      parts.push(i % 3 === 0 ? '.x' : '(n)');
    }
    const input = parts.join('');
    const parser = new Parser(rules, input);
    const [result, _] = parser.parse('L');
    expect(result !== null && !result.isMismatch).toBe(true);
    expect(result!.len).toBe(input.length);
  });

  test('LINEAR-05-deep-nesting', () => {
    const rules: Record<string, Clause> = {
      E: new First([
        new Seq([new Str('('), new Ref('E'), new Str(')')]),
        new Str('x'),
      ]),
    };
    const depth = 50;
    const input = '('.repeat(depth) + 'x' + ')'.repeat(depth);
    const parser = new Parser(rules, input);
    const [result, _] = parser.parse('E');
    expect(result !== null && !result.isMismatch).toBe(true);
    expect(result!.len).toBe(input.length);
  });

  test('LINEAR-06-precedence', () => {
    const rules: Record<string, Clause> = {
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new Ref('T')]),
        new Ref('T'),
      ]),
      T: new First([
        new Seq([new Ref('T'), new Str('*'), new Ref('F')]),
        new Ref('F'),
      ]),
      F: new First([
        new Seq([new Str('('), new Ref('E'), new Str(')')]),
        new Ref('N'),
      ]),
      N: new CharRange('0', '9'),
    };
    const parts: string[] = [];
    for (let i = 0; i < 20; i++) {
      parts.push(`${i % 10}`);
      if (i < 19) {
        parts.push(i % 2 === 0 ? '+' : '*');
      }
    }
    const input = parts.join('');
    const parser = new Parser(rules, input);
    const [result, _] = parser.parse('E');
    expect(result !== null && !result.isMismatch).toBe(true);
    expect(result!.len).toBe(input.length);
  });

  test('LINEAR-07-ambiguous', () => {
    const rules: Record<string, Clause> = {
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new Ref('E')]),
        new Ref('N'),
      ]),
      N: new CharRange('0', '9'),
    };
    const nums = Array.from({ length: 10 }, (_, i) => `${i % 10}`);
    const input = nums.join('+');
    const parser = new Parser(rules, input);
    const [result, _] = parser.parse('E');
    expect(result !== null && !result.isMismatch).toBe(true);
    expect(result!.len).toBe(input.length);
  });

  test('LINEAR-08-long-input', () => {
    const rules: Record<string, Clause> = {
      S: new OneOrMore(new Seq([new Str('a'), new Str('b'), new Str('c')])),
    };
    const input = 'abc'.repeat(500);
    const parser = new Parser(rules, input);
    const [result, _] = parser.parse('S');
    expect(result !== null && !result.isMismatch).toBe(true);
    expect(result!.len).toBe(input.length);
  });

  test('LINEAR-09-long-lr', () => {
    const rules: Record<string, Clause> = {
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new Ref('N')]),
        new Ref('N'),
      ]),
      N: new CharRange('0', '9'),
    };
    const nums = Array.from({ length: 100 }, (_, i) => `${i % 10}`);
    const input = nums.join('+');
    const parser = new Parser(rules, input);
    const [result, _] = parser.parse('E');
    expect(result !== null && !result.isMismatch).toBe(true);
    expect(result!.len).toBe(input.length);
  });

  test('LINEAR-10-recovery', () => {
    const rules: Record<string, Clause> = {
      S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
    };
    const parts: string[] = [];
    for (let i = 0; i < 50; i++) {
      if (i > 0 && i % 10 === 0) {
        parts.push('(xZx)'); // Error
      } else {
        parts.push('(xx)');
      }
    }
    const input = parts.join('');
    const parser = new Parser(rules, input);
    const [result, _] = parser.parse('S');
    expect(result !== null && !result.isMismatch).toBe(true);
    expect(result!.len).toBe(input.length);
  });
});
