/**
 * ONEORMORE FIRST-ITERATION RECOVERY TESTS (FIX #10 Verification)
 *
 * These tests verify that OneOrMore allows recovery on the first iteration
 * while still maintaining "at least one match" semantics.
 */

import { describe, expect, test } from '@jest/globals';
import { OneOrMore, Seq, Str, ZeroOrMore } from '../src';
import { parse } from './testUtils';

describe('OneOrMore First-Iteration Recovery Tests', () => {
  test('OM-01-first-clean', () => {
    // Baseline: First iteration succeeds cleanly
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('ab')) }, 'ababab');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('OM-02-no-match-anywhere', () => {
    // OneOrMore still requires at least one match
    const [ok, _, __] = parse({ S: new OneOrMore(new Str('ab')) }, 'xyz');
    expect(ok).toBe(false);
  });

  test('OM-03-skip-to-first-match', () => {
    // FIX #10: Skip garbage to find first match
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('ab')) }, 'Xab');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip.some(s => s.includes('X'))).toBe(true);
  });

  test('OM-04-skip-multiple-to-first', () => {
    // FIX #10: Skip multiple characters to find first match
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('ab')) }, 'XXXXXab');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip.some(s => s.includes('XXXXX'))).toBe(true);
  });

  test('OM-05-multiple-iterations-with-errors', () => {
    // FIX #10: First iteration with error, then more iterations with errors
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('ab')) }, 'XabYabZab');
    expect(ok).toBe(true);
    expect(err).toBe(3);
    expect(skip.some(s => s.includes('X'))).toBe(true);
    expect(skip.some(s => s.includes('Y'))).toBe(true);
    expect(skip.some(s => s.includes('Z'))).toBe(true);
  });

  test('OM-06-first-with-error-then-clean', () => {
    // First iteration skips error, subsequent iterations clean
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('ab')) }, 'Xabababab');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip.some(s => s.includes('X'))).toBe(true);
  });

  test('OM-07-vs-zeoormore-semantics', () => {
    // BOTH ZeroOrMore and OneOrMore fail on input with no matches
    // because parseWithRecovery requires parsing the ENTIRE input.
    // ZeroOrMore matches 0 times (len=0), leaving "XYZ" unparsed.
    // OneOrMore matches 0 times (fails "at least one"), also leaving input unparsed.

    // Key difference: Empty input
    const zr_empty = parse({ S: new ZeroOrMore(new Str('ab')) }, '');
    expect(zr_empty[0]).toBe(true);
    expect(zr_empty[1]).toBe(0);

    const or_empty = parse({ S: new OneOrMore(new Str('ab')) }, '');
    expect(or_empty[0]).toBe(false);

    // Key difference: With valid matches
    const zr_match = parse({ S: new ZeroOrMore(new Str('ab')) }, 'ababab');
    expect(zr_match[0]).toBe(true);

    const or_match = parse({ S: new OneOrMore(new Str('ab')) }, 'ababab');
    expect(or_match[0]).toBe(true);
  });

  test('OM-08-long-skip-performance', () => {
    // Large skip distance should still complete quickly
    const input = 'X'.repeat(100) + 'ab';
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('ab')) }, input);
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip[0].length).toBe(100);
  });

  test('OM-09-exhaustive-search-no-match', () => {
    // Try all positions, find nothing, fail cleanly
    const input = 'X'.repeat(50) + 'Y'.repeat(50); // No 'ab' anywhere
    const [ok, _, __] = parse({ S: new OneOrMore(new Str('ab')) }, input);
    expect(ok).toBe(false);
  });

  test('OM-10-first-iteration-with-bound', () => {
    // First iteration recovery + bound checking
    const [ok, err, skip] = parse(
      {
        S: new Seq([new OneOrMore(new Str('ab')), new Str('end')]),
      },
      'XabYabend'
    );
    expect(ok).toBe(true);
    expect(err).toBe(2);
    expect(skip.some(s => s.includes('X'))).toBe(true);
    expect(skip.some(s => s.includes('Y'))).toBe(true);
  });

  test('OM-11-alternating-pattern', () => {
    // Pattern: error, match, error, match, ...
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('ab')) }, 'XabXabXabXab');
    expect(ok).toBe(true);
    expect(err).toBe(4);
  });

  test('OM-12-multi-char-terminal-first', () => {
    // Multi-character terminal with first-iteration recovery
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('hello')) }, 'XXXhellohello');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip.some(s => s.includes('XXX'))).toBe(true);
  });
});
