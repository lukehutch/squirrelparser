// ===========================================================================
// ONEORMORE FIRST-ITERATION RECOVERY TESTS (FIX #10 Verification)
// ===========================================================================
// These tests verify that OneOrMore allows recovery on the first iteration
// while still maintaining "at least one match" semantics.

import { testParse } from './testUtils.js';

describe('OneOrMore First-Iteration Recovery Tests', () => {
  test('OM-01-first-clean', () => {
    // Baseline: First iteration succeeds cleanly
    const { ok, errorCount } = testParse('S <- "ab"+ ;', 'ababab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('OM-02-no-match-anywhere', () => {
    // OneOrMore still requires at least one match
    const { ok } = testParse('S <- "ab"+ ;', 'xyz');
    expect(ok).toBe(false);
  });

  test('OM-03-skip-to-first-match', () => {
    // FIX #10: Skip garbage to find first match
    const { ok, errorCount, skippedStrings } = testParse('S <- "ab"+ ;', 'Xab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
  });

  test('OM-04-skip-multiple-to-first', () => {
    // FIX #10: Skip multiple characters to find first match
    const { ok, errorCount, skippedStrings } = testParse('S <- "ab"+ ;', 'XXXXXab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('XXXXX');
  });

  test('OM-05-multiple-iterations-with-errors', () => {
    // FIX #10: First iteration with error, then more iterations with errors
    const { ok, errorCount, skippedStrings } = testParse('S <- "ab"+ ;', 'XabYabZab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(3);
    expect(skippedStrings).toContain('X');
    expect(skippedStrings).toContain('Y');
    expect(skippedStrings).toContain('Z');
  });

  test('OM-06-first-with-error-then-clean', () => {
    // First iteration skips error, subsequent iterations clean
    const { ok, errorCount, skippedStrings } = testParse('S <- "ab"+ ;', 'Xabababab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
  });

  test('OM-07-vs-zeroormore-semantics', () => {
    // BOTH ZeroOrMore and OneOrMore fail on input with no matches
    // because parseWithRecovery requires parsing the ENTIRE input.
    // ZeroOrMore matches 0 times (len=0), leaving "XYZ" unparsed.
    // OneOrMore matches 0 times (fails "at least one"), also leaving input unparsed.

    // Key difference: Empty input
    const zrEmpty = testParse('S <- "ab"* ;', '');
    expect(zrEmpty.ok).toBe(true);
    expect(zrEmpty.errorCount).toBe(0);

    const orEmpty = testParse('S <- "ab"+ ;', '');
    expect(orEmpty.ok).toBe(false);

    // Key difference: With valid matches
    const zrMatch = testParse('S <- "ab"* ;', 'ababab');
    expect(zrMatch.ok).toBe(true);

    const orMatch = testParse('S <- "ab"+ ;', 'ababab');
    expect(orMatch.ok).toBe(true);
  });

  test('OM-08-long-skip-performance', () => {
    // Large skip distance should still complete quickly
    const input = 'X'.repeat(100) + 'ab';
    const { ok, errorCount, skippedStrings } = testParse('S <- "ab"+ ;', input);
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings[0].length).toBe(100);
  });

  test('OM-09-exhaustive-search-no-match', () => {
    // Try all positions, find nothing, fail cleanly
    const input = 'X'.repeat(50) + 'Y'.repeat(50); // No 'ab' anywhere
    const { ok } = testParse('S <- "ab"+ ;', input);
    expect(ok).toBe(false);
  });

  test('OM-10-first-iteration-with-bound', () => {
    // First iteration recovery + bound checking
    const { ok, errorCount, skippedStrings } = testParse('S <- "ab"+ "end" ;', 'XabYabend');
    expect(ok).toBe(true);
    expect(errorCount).toBe(2);
    expect(skippedStrings).toContain('X');
    expect(skippedStrings).toContain('Y');
  });

  test('OM-11-alternating-pattern', () => {
    // Pattern: error, match, error, match, ...
    const { ok, errorCount } = testParse('S <- "ab"+ ;', 'XabXabXabXab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(4);
  });

  test('OM-12-multi-char-terminal-first', () => {
    // Multi-character terminal with first-iteration recovery
    const { ok, errorCount, skippedStrings } = testParse('S <- "hello"+ ;', 'XXXhellohello');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('XXX');
  });
});
