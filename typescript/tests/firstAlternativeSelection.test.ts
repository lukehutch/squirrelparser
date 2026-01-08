/**
 * FIRST ALTERNATIVE SELECTION TESTS (FIX #2 Verification)
 * These tests verify that First correctly selects alternatives based on
 * length priority (longer matches preferred) with error count as tiebreaker.
 */

import { describe, expect, test } from '@jest/globals';
import { First, OneOrMore, Ref, Seq, Str } from '../src';
import { parse } from './testUtils';

describe('First Alternative Selection Tests', () => {
  test('FIRST-01-all-alternatives-fail-cleanly', () => {
    // All alternatives mismatch, no recovery possible
    const [ok, _, __] = parse(
      {
        S: new First([new Str('a'), new Str('b'), new Str('c')]),
      },
      'x'
    );
    expect(ok).toBe(false); // should fail (no alternative matches)
  });

  test('FIRST-02-first-needs-recovery-second-clean', () => {
    // FIX #2: Prefer longer matches, so first alternative wins despite error
    const [ok, err, _] = parse(
      {
        S: new First([new Seq([new Str('a'), new Str('b')]), new Str('c')]),
      },
      'aXb'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // first alternative chosen (longer despite error)
  });

  test('FIRST-03-all-alternatives-need-recovery', () => {
    // Multiple alternatives with recovery, choose best
    const [ok, err, _] = parse(
      {
        S: new First([
          new Seq([new Str('a'), new Str('b'), new Str('c')]), // aXbc: len=4, 1 error
          new Seq([new Str('a'), new Str('y'), new Str('z')]), // would need different recovery
        ]),
      },
      'aXbc'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should choose first alternative (matches with recovery)
  });

  test('FIRST-04-longer-with-error-vs-shorter-clean', () => {
    // FIX #2: Length priority - longer wins even with error
    const [ok, err, _] = parse(
      {
        S: new First([
          new Seq([new Str('a'), new Str('b'), new Str('c')]), // len=3, 1 error
          new Str('a'), // len=1, 0 errors
        ]),
      },
      'aXbc'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should choose first (longer despite error)
  });

  test('FIRST-05-same-length-fewer-errors-wins', () => {
    // Same length, fewer errors wins
    const [ok, err, _] = parse(
      {
        S: new First([
          new Seq([new Str('a'), new Str('b'), new Str('c'), new Str('d')]), // aXYcd: len=5, 2 errors
          new Seq([new Str('a'), new Str('b'), new Str('c')]), // aXbc: len=4, 1 error
        ]),
      },
      'aXbc'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should choose second (fewer errors)
  });

  test('FIRST-06-multiple-clean-alternatives', () => {
    // Multiple alternatives match cleanly, first wins
    const [ok, err, _] = parse(
      {
        S: new First([
          new Str('abc'),
          new Str('abc'), // Same as first
          new Str('ab'),
        ]),
      },
      'abc'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors (clean match)
    // First alternative wins
  });

  test('FIRST-07-prefer-longer-clean-over-shorter-clean', () => {
    // Two clean alternatives, different lengths
    const [ok, err, _] = parse(
      {
        S: new First([new Str('abc'), new Str('ab')]),
      },
      'abc'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
    // First matches full input (len=3), second would match len=2
    // But First tries in order, so first wins anyway
  });

  test('FIRST-08-fallback-after-all-longer-fail', () => {
    // Longer alternatives fail, shorter succeeds
    const [ok, err, _] = parse(
      {
        S: new First([new Seq([new Str('x'), new Str('y'), new Str('z')]), new Str('a')]),
      },
      'a'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors (clean second alternative)
  });

  test('FIRST-09-left-recursive-alternative', () => {
    // First contains left-recursive alternative
    const [ok, err, _] = parse(
      {
        E: new First([new Seq([new Ref('E'), new Str('+'), new Str('n')]), new Str('n')]),
      },
      'n+Xn',
      'E'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    // LR expansion with recovery
  });

  test('FIRST-10-nested-first', () => {
    // First containing another First
    const [ok, err, _] = parse(
      {
        S: new First([new First([new Str('a'), new Str('b')]), new Str('c')]),
      },
      'b'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
    // Outer First tries first alternative (inner First), which matches 'b'
  });

  test('FIRST-11-all-alternatives-incomplete', () => {
    // All alternatives incomplete (don't consume full input)
    // With new invariant, best match selected, trailing captured
    const [ok, err, skip] = parse(
      {
        S: new First([new Str('a'), new Str('b')]),
      },
      'aXXX'
    );
    expect(ok).toBe(true); // should succeed with trailing captured
    expect(err).toBe(1); // should have 1 error (trailing XXX)
    expect(skip.includes('XXX')).toBe(true); // should capture XXX
  });

  test('FIRST-12-recovery-with-complex-alternatives', () => {
    // Complex alternatives with nested structures
    const [ok, err, _] = parse(
      {
        S: new First([
          new Seq([new OneOrMore(new Str('x')), new Str('y')]),
          new Seq([new OneOrMore(new Str('a')), new Str('b')]),
        ]),
      },
      'xxxXy'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should choose first alternative
  });
});
