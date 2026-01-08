/**
 * ERROR LOCALIZATION TESTS (Non-Cascading Verification)
 * These tests verify that errors don't cascade - each error is localized
 * to its specific location without affecting subsequent parsing.
 */

import { describe, expect, test } from '@jest/globals';
import { First, OneOrMore, Ref, Seq, Str } from '../src';
import { parse } from './testUtils';

describe('Error Localization (Non-Cascading) Tests', () => {
  test('CASCADE-01-error-in-first-element-doesnt-affect-second', () => {
    // Error in first element, second element parses cleanly
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c')]),
      },
      'aXbc'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('X');
    // Error localized to position 1, doesn't cascade to 'b' or 'c'
  });

  test('CASCADE-02-error-in-nested-structure', () => {
    // Error inside inner Seq, doesn't affect outer Seq
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Seq([new Str('a'), new Str('b')]), new Str('c')]),
      },
      'aXbc'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('X');
    // Error in inner Seq (between 'a' and 'b'), outer Seq continues normally
  });

  test('CASCADE-03-lr-error-doesnt-cascade-to-next-expansion', () => {
    // Error in one LR expansion iteration, next iteration clean
    const [ok, err, skip] = parse(
      {
        E: new First([new Seq([new Ref('E'), new Str('+'), new Str('n')]), new Str('n')]),
      },
      'n+Xn+n',
      'E'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('X');
    // Expansion: n (base), n+[skip X]n, n+Xn+n
    // First '+' clean, second '+' has error, third '+' clean
    // Error localized to second iteration
  });

  test('CASCADE-04-multiple-independent-errors', () => {
    // Multiple errors in different parts of parse, all localized
    const [ok, err, skip] = parse(
      {
        S: new Seq([
          new Seq([new Str('a'), new Str('b')]),
          new Seq([new Str('c'), new Str('d')]),
          new Seq([new Str('e'), new Str('f')]),
        ]),
      },
      'aXbcYdeZf'
    );
    expect(ok).toBe(true);
    expect(err).toBe(3);
    expect(skip).toContain('X');
    expect(skip).toContain('Y');
    expect(skip).toContain('Z');
    // Each error localized to its respective Seq
  });

  test('CASCADE-05-error-before-repetition', () => {
    // Error before repetition, repetition parses cleanly
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Str('a'), new OneOrMore(new Str('b'))]),
      },
      'aXbbb'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('X');
    // Error at position 1, OneOrMore starts cleanly at position 2
  });

  test('CASCADE-06-error-after-repetition', () => {
    // Repetition clean, error after it
    const [ok, err, skip] = parse(
      {
        S: new Seq([new OneOrMore(new Str('a')), new Str('b')]),
      },
      'aaaXb'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('X');
    // OneOrMore matches 3 a's cleanly, then error, then 'b'
  });

  test('CASCADE-07-error-in-first-alternative-doesnt-poison-second', () => {
    // First alternative has error, second alternative clean
    const [ok, err, _] = parse(
      {
        S: new First([new Seq([new Str('a'), new Str('b')]), new Str('c')]),
      },
      'c'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
    // First tries and fails, second succeeds cleanly - no cascade
  });

  test('CASCADE-08-recovery-version-increments-correctly', () => {
    // Each recovery increments version, ensuring proper cache invalidation
    const [ok, err, _] = parse(
      {
        S: new Seq([
          new Seq([new Str('a'), new Str('b')]),
          new Seq([new Str('c'), new Str('d')]),
        ]),
      },
      'aXbcYd'
    );
    expect(ok).toBe(true);
    expect(err).toBe(2);
    // Two recoveries, each increments version, no cache pollution
  });

  test('CASCADE-09-error-at-deeply-nested-level', () => {
    // Error very deep in nesting, doesn't affect outer levels
    const [ok, err, skip] = parse(
      {
        S: new Seq([
          new Seq([
            new Seq([new Seq([new Str('a'), new Str('b')]), new Str('c')]),
            new Str('d'),
          ]),
          new Str('e'),
        ]),
      },
      'aXbcde'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('X');
    // Error localized despite 4 levels of nesting
  });

  test('CASCADE-10-error-recovery-doesnt-leave-parser-in-bad-state', () => {
    // After recovery, parser continues with clean state
    const [ok, err, _] = parse(
      {
        S: new Seq([
          new Seq([new Str('a'), new Str('b')]),
          new Str('c'), // Expects 'c' at position 2
          new Seq([new Str('d'), new Str('e')]),
        ]),
      },
      'abXcde'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    // After skipping X at position 2, matches 'c' at position 3, then 'de'
  });
});
