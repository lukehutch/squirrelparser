// ===========================================================================
// FIRST ALTERNATIVE SELECTION TESTS (FIX #2 Verification)
// ===========================================================================
// These tests verify that First correctly selects alternatives based on
// length priority (longer matches preferred) with error count as tiebreaker.

import { testParse } from './testUtils.js';

describe('First Alternative Selection Tests', () => {
  test('FIRST-01-all-alternatives-fail-cleanly', () => {
    // All alternatives mismatch, no recovery possible
    const { ok } = testParse('S <- "a" / "b" / "c" ;', 'x');
    expect(ok).toBe(false);
  });

  test('FIRST-02-first-needs-recovery-second-clean', () => {
    // FIX #2: Prefer longer matches, so first alternative wins despite error
    const { ok, errorCount } = testParse('S <- "a" "b" / "c" ;', 'aXb');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
  });

  test('FIRST-03-all-alternatives-need-recovery', () => {
    // Multiple alternatives with recovery, choose best
    const { ok, errorCount } = testParse('S <- "a" "b" "c" / "a" "y" "z" ;', 'aXbc');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
  });

  test('FIRST-04-longer-with-error-vs-shorter-clean', () => {
    // FIX #2: Length priority - longer wins even with error
    const { ok, errorCount } = testParse('S <- "a" "b" "c" / "a" ;', 'aXbc');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
  });

  test('FIRST-05-same-length-fewer-errors-wins', () => {
    // Same length, fewer errors wins
    const { ok, errorCount } = testParse('S <- "a" "b" "c" "d" / "a" "b" "c" ;', 'aXbc');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
  });

  test('FIRST-06-multiple-clean-alternatives', () => {
    // Multiple alternatives match cleanly, first wins
    const { ok, errorCount } = testParse('S <- "abc" / "abc" / "ab" ;', 'abc');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // First alternative wins
  });

  test('FIRST-07-prefer-longer-clean-over-shorter-clean', () => {
    // Two clean alternatives, different lengths
    const { ok, errorCount } = testParse('S <- "abc" / "ab" ;', 'abc');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // First matches full input (len=3), second would match len=2
    // But First tries in order, so first wins anyway
  });

  test('FIRST-08-fallback-after-all-longer-fail', () => {
    // Longer alternatives fail, shorter succeeds
    const { ok, errorCount } = testParse('S <- "x" "y" "z" / "a" ;', 'a');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('FIRST-09-left-recursive-alternative', () => {
    // First contains left-recursive alternative
    const { ok, errorCount } = testParse('E <- E "+" "n" / "n" ;', 'n+Xn', 'E');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    // LR expansion with recovery
  });

  test('FIRST-10-nested-first', () => {
    // First containing another First
    const { ok, errorCount } = testParse('S <- ("a" / "b") / "c" ;', 'b');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // Outer First tries first alternative (inner First), which matches 'b'
  });

  test('FIRST-11-all-alternatives-incomplete', () => {
    // All alternatives incomplete (don't consume full input)
    // With new invariant, best match selected, trailing captured
    const { ok, errorCount, skippedStrings } = testParse('S <- "a" / "b" ;', 'aXXX');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('XXX');
  });

  test('FIRST-12-recovery-with-complex-alternatives', () => {
    // Complex alternatives with nested structures
    const { ok, errorCount } = testParse('S <- "x"+ "y" / "a"+ "b" ;', 'xxxXy');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
  });
});
