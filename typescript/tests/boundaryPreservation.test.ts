// ===========================================================================
// BOUNDARY PRESERVATION TESTS
// ===========================================================================
// These tests verify that recovery doesn't consume content meant for
// subsequent grammar elements (preserve structural boundaries).

import { testParse } from './testUtils.js';

describe('Boundary Preservation Tests', () => {
  test('BND-01-dont-consume-next-terminal', () => {
    // Recovery should skip 'X' but not consume 'b' (needed by next element)
    const { ok, errorCount, skippedStrings } = testParse('S <- "a" "b" ;', 'aXb');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
    // Verify 'b' was matched by second element, not consumed during recovery
  });

  test('BND-02-dont-partially-consume-next-terminal', () => {
    // Multi-char terminals are atomic - recovery can't consume part of 'cd'
    const { ok, errorCount, skippedStrings } = testParse('S <- "ab" "cd" ;', 'abXcd');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
    // 'cd' should be matched atomically by second element
  });

  test('BND-03-recovery-in-first-doesnt-poison-alternatives', () => {
    // First alternative fails cleanly, second succeeds
    const { ok, errorCount } = testParse('S <- "a" "b" / "c" "d" ;', 'cd');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('BND-04-first-alternative-with-recovery-vs-second-clean', () => {
    // First alternative needs recovery, second is clean
    // Should prefer first (longer match, see FIX #2)
    const { ok, errorCount } = testParse('S <- "a" "b" "c" / "a" ;', 'aXbc');
    expect(ok).toBe(true);
    // FIX #2: Prefer longer matches over fewer errors
    expect(errorCount).toBe(1);
  });

  test('BND-05-boundary-with-nested-repetition', () => {
    // Repetition with bound should stop at delimiter
    const { ok, errorCount } = testParse('S <- "x"+ ";" "y"+ ;', 'xxx;yyy');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // x+ stops at ';', y+ stops at EOF
  });

  test('BND-06-boundary-with-recovery-before-delimiter', () => {
    // Recovery happens, but delimiter is preserved
    const { ok, errorCount, skippedStrings } = testParse('S <- "x"+ ";" "y"+ ;', 'xxXx;yyy');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
    // ';' should not be consumed during recovery of x+
  });

  test('BND-07-probe-respects-boundaries', () => {
    // ZeroOrMore probes ahead to find boundary
    const { ok, errorCount } = testParse('S <- "x"* ("y" / "z") ;', 'xxxz');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // ZeroOrMore should probe, find 'z' matches First, stop before it
  });

  test('BND-08-complex-boundary-nesting', () => {
    // Nested sequences with multiple boundaries
    const { ok, errorCount } = testParse('S <- ("a"+ "+") ("b"+ "=") ;', 'aaa+bbb=');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // Each repetition stops at its delimiter
  });

  test('BND-09-boundary-with-eof', () => {
    // No explicit boundary - should consume until EOF
    const { ok, errorCount } = testParse('S <- "x"+ ;', 'xxxxx');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // Consumes all x's (no boundary to stop at)
  });

  test('BND-10-recovery-near-boundary', () => {
    // Error just before boundary - should not cross boundary
    const { ok, errorCount, skippedStrings } = testParse('S <- "x"+ ";" ;', 'xxX;');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
    // ';' should remain for second element
  });
});
