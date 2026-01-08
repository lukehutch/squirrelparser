/**
 * SECTION 5: FIX #5/#6 - OPTIONAL AND EOF (25 tests)
 */

import { describe, expect, test } from '@jest/globals';
import type { Clause } from '../src';
import { First, OneOrMore, Optional, Parser, Ref, Seq, Str } from '../src';
import { countDeletions, parse } from './testUtils';

describe('FIX #5/#6 - OPTIONAL AND EOF', () => {
  // Mutual recursion grammar
  const mr: Record<string, Clause> = {
    S: new Ref('A'),
    A: new First([new Seq([new Str('a'), new Ref('B')]), new Str('y')]),
    B: new First([new Seq([new Str('b'), new Ref('A')]), new Str('x')]),
  };

  test('F5-01-aby', () => {
    const [ok, err, _] = parse(mr, 'aby');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F5-02-abZy', () => {
    const [ok, err, skip] = parse(mr, 'abZy');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F5-03-ababy', () => {
    const [ok, err, _] = parse(mr, 'ababy');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F5-04-ax', () => {
    const [ok, err, _] = parse(mr, 'ax');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F5-05-y', () => {
    const [ok, err, _] = parse(mr, 'y');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F5-06-abx', () => {
    // 'abx' is NOT in the language: after 'ab' we need A which requires 'a' or 'y', not 'x'
    // Grammar produces: y, ax, aby, abax, ababy, etc.
    // So this requires error recovery (skip 'b' and match 'ax', or skip 'bx' and fail)
    const [ok, err, _] = parse(mr, 'abx');
    expect(ok).toBe(true); // should succeed with recovery
    expect(err).toBeGreaterThanOrEqual(1); // should have at least 1 error
  });

  test('F5-06b-abax', () => {
    // 'abax' IS in the language: A → a B → a b A → a b a B → a b a x
    const [ok, err, _] = parse(mr, 'abax');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F5-07-ababx', () => {
    // 'ababx' is NOT in the language: after 'abab' we need A which requires 'a' or 'y', not 'x'
    // Grammar produces: y, ax, aby, abax, ababy, ababax, abababy, etc.
    // So this requires error recovery
    const [ok, err, _] = parse(mr, 'ababx');
    expect(ok).toBe(true); // should succeed with recovery
    expect(err).toBeGreaterThanOrEqual(1); // should have at least 1 error
  });

  test('F5-07b-ababax', () => {
    // 'ababax' IS in the language: A → a B → a b A → a b a B → a b a b A → a b a b a B → a b a b a x
    const [ok, err, _] = parse(mr, 'ababax');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F6-01-Optional wrapper', () => {
    const [ok, err, skip] = parse(
      {
        S: new Optional(new Seq([new OneOrMore(new Str('x')), new Str('!')])),
      },
      'xZx!'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F6-02-Optional at EOF', () => {
    const [ok, err, _] = parse({ S: new Optional(new Str('x')) }, '');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F6-03-Nested optional', () => {
    const [ok, err, skip] = parse(
      {
        S: new Optional(new Optional(new Seq([new OneOrMore(new Str('x')), new Str('!')]))),
      },
      'xZx!'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F6-04-Optional in Seq', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Optional(new Seq([new OneOrMore(new Str('x'))])), new Str('!')]),
      },
      'xZx!'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F6-05-EOF del ok', () => {
    const parser = new Parser(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c')]),
      },
      'ab'
    );
    const [result, _] = parser.parse('S');
    expect(result !== null && !result.isMismatch).toBe(true); // should succeed with recovery
    expect(countDeletions(result) === 1).toBe(true); // should have 1 deletion
  });
});
