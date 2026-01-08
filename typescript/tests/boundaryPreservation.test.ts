/**
 * BOUNDARY PRESERVATION TESTS
 * These tests verify that recovery doesn't consume content meant for
 * subsequent grammar elements (preserve structural boundaries).
 */

import { describe, expect, test } from '@jest/globals';
import { First, OneOrMore, Seq, Str, ZeroOrMore } from '../src';
import { parse } from './testUtils';

describe('Boundary Preservation Tests', () => {
  test('BND-01-dont-consume-next-terminal', () => {
    // Recovery should skip 'X' but not consume 'b' (needed by next element)
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Str('a'), new Str('b')]),
      },
      'aXb'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('X')).toBe(true); // should skip X
    // Verify 'b' was matched by second element, not consumed during recovery
  });

  test('BND-02-dont-partially-consume-next-terminal', () => {
    // Multi-char terminals are atomic - recovery can't consume part of 'cd'
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Str('ab'), new Str('cd')]),
      },
      'abXcd'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('X')).toBe(true); // should skip X
    // 'cd' should be matched atomically by second element
  });

  test('BND-03-recovery-in-first-doesnt-poison-alternatives', () => {
    // First alternative fails cleanly, second succeeds
    const [ok, err, _] = parse(
      {
        S: new First([
          new Seq([new Str('a'), new Str('b')]),
          new Seq([new Str('c'), new Str('d')]),
        ]),
      },
      'cd'
    );
    expect(ok).toBe(true); // should succeed (second alternative)
    expect(err).toBe(0); // should have 0 errors (clean match)
  });

  test('BND-04-first-alternative-with-recovery-vs-second-clean', () => {
    // First alternative needs recovery, second is clean
    // Should prefer first (longer match, see FIX #2)
    const [ok, err, _] = parse(
      {
        S: new First([
          new Seq([new Str('a'), new Str('b'), new Str('c')]),
          new Str('a'),
        ]),
      },
      'aXbc'
    );
    expect(ok).toBe(true); // should succeed
    // FIX #2: Prefer longer matches over fewer errors
    expect(err).toBe(1); // should choose first alternative (longer despite error)
  });

  test('BND-05-boundary-with-nested-repetition', () => {
    // Repetition with bound should stop at delimiter
    const [ok, err, _] = parse(
      {
        S: new Seq([new OneOrMore(new Str('x')), new Str(';'), new OneOrMore(new Str('y'))]),
      },
      'xxx;yyy'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
    // x+ stops at ';', y+ stops at EOF
  });

  test('BND-06-boundary-with-recovery-before-delimiter', () => {
    // Recovery happens, but delimiter is preserved
    const [ok, err, skip] = parse(
      {
        S: new Seq([new OneOrMore(new Str('x')), new Str(';'), new OneOrMore(new Str('y'))]),
      },
      'xxXx;yyy'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('X')).toBe(true); // should skip X
    // ';' should not be consumed during recovery of x+
  });

  test('BND-07-probe-respects-boundaries', () => {
    // ZeroOrMore probes ahead to find boundary
    const [ok, err, _] = parse(
      {
        S: new Seq([new ZeroOrMore(new Str('x')), new First([new Str('y'), new Str('z')])]),
      },
      'xxxz'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
    // ZeroOrMore should probe, find 'z' matches First, stop before it
  });

  test('BND-08-complex-boundary-nesting', () => {
    // Nested sequences with multiple boundaries
    const [ok, err, _] = parse(
      {
        S: new Seq([
          new Seq([new OneOrMore(new Str('a')), new Str('+')]),
          new Seq([new OneOrMore(new Str('b')), new Str('=')]),
        ]),
      },
      'aaa+bbb='
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
    // Each repetition stops at its delimiter
  });

  test('BND-09-boundary-with-eof', () => {
    // No explicit boundary - should consume until EOF
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('x')) }, 'xxxxx');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
    // Consumes all x's (no boundary to stop at)
  });

  test('BND-10-recovery-near-boundary', () => {
    // Error just before boundary - should not cross boundary
    const [ok, err, skip] = parse(
      {
        S: new Seq([new OneOrMore(new Str('x')), new Str(';')]),
      },
      'xxX;'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('X')).toBe(true); // should skip X
    // ';' should remain for second element
  });
});
