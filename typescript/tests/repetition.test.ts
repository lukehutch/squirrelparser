// ===========================================================================
// SECTION 6: REPETITION COMPREHENSIVE (20 tests)
// ===========================================================================

import { testParse } from './testUtils.js';

describe('Repetition Comprehensive', () => {
  test('R01-between', () => {
    const { ok, errorCount, skippedStrings } = testParse('S <- "ab"+ ;', 'abXXab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('XX');
  });

  test('R02-multi', () => {
    const { ok, errorCount, skippedStrings } = testParse('S <- "ab"+ ;', 'abXabYab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(2);
    expect(skippedStrings).toContain('X');
    expect(skippedStrings).toContain('Y');
  });

  test('R03-long skip', () => {
    const { ok, errorCount } = testParse('S <- "ab"+ ;', 'ab' + 'X'.repeat(50) + 'ab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
  });

  test('R04-ZeroOrMore start', () => {
    const { ok, errorCount, skippedStrings } = testParse('S <- "ab"* "!" ;', 'XXab!');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('XX');
  });

  test('R05-before first', () => {
    // FIX #10: OneOrMore now allows first-iteration recovery
    const { ok, errorCount, skippedStrings } = testParse('S <- "ab"+ ;', 'XXab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('XX');
  });

  test('R06-trailing captured', () => {
    // With new invariant, trailing errors are captured in parse tree
    const { ok, errorCount, skippedStrings } = testParse('S <- "ab"+ ;', 'ababXX');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('XX');
  });

  test('R07-single', () => {
    const { ok, errorCount } = testParse('S <- "ab"+ ;', 'ab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('R08-ZeroOrMore empty', () => {
    const { ok, errorCount } = testParse('S <- "ab"* ;', '');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('R09-alternating', () => {
    const { ok, errorCount } = testParse('S <- "ab"+ ;', 'abXabXabXab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(3);
  });

  test('R10-long clean', () => {
    const { ok, errorCount } = testParse('S <- "x"+ ;', 'x'.repeat(100));
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('R11-long err', () => {
    const { ok, errorCount, skippedStrings } = testParse(
      'S <- "x"+ ;',
      'x'.repeat(50) + 'Z' + 'x'.repeat(49)
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('Z');
  });

  test('R12-20 errors', () => {
    const input = Array(20).fill('abZ').join('') + 'ab';
    const { ok, errorCount } = testParse('S <- "ab"+ ;', input);
    expect(ok).toBe(true);
    expect(errorCount).toBe(20);
  });

  test('R13-very long', () => {
    const { ok, errorCount } = testParse('S <- "ab"+ ;', 'ab'.repeat(500));
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('R14-very long err', () => {
    const { ok, errorCount } = testParse(
      'S <- "ab"+ ;',
      'ab'.repeat(250) + 'ZZ' + 'ab'.repeat(249)
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
  });

  // Tests for trailing error recovery (Issue: abxbxax failing completely)
  // These tests ensure that after recovering from errors in the middle,
  // the parser also captures trailing unmatched input as errors.

  test('R15-trailing single char after recovery', () => {
    // After recovering from middle errors, trailing 'x' should also be caught as error
    const { ok, errorCount, skippedStrings } = testParse(
      `
      S <- A ;
      A <- ("a" / "b")+ ;
    `,
      'abxbxax'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(3);
    expect(skippedStrings).toHaveLength(3);
  });

  test('R16-trailing multiple chars after recovery', () => {
    // Multiple trailing errors after recovery
    const { ok, errorCount, skippedStrings } = testParse('S <- "ab"+ ;', 'abXabXabXX');
    expect(ok).toBe(true);
    expect(errorCount).toBe(3);
    expect(skippedStrings).toHaveLength(3);
  });

  test('R17-trailing long error after recovery', () => {
    // Long trailing error after recovery
    const { ok, errorCount } = testParse(
      'S <- "x"+ ;',
      'x'.repeat(50) + 'Z' + 'x'.repeat(49) + 'YYYY'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(2);
  });

  test('R18-trailing after multiple alternating errors', () => {
    // Multiple errors throughout, then trailing error
    const { ok, errorCount } = testParse('S <- "ab"+ ;', 'abXabYabZabXX');
    expect(ok).toBe(true);
    expect(errorCount).toBe(4);
  });

  test('R19-single char after first recovery', () => {
    // Recovery on first iteration, then trailing error
    const { ok, errorCount, skippedStrings } = testParse('S <- "ab"+ ;', 'XXabX');
    expect(ok).toBe(true);
    expect(errorCount).toBe(2);
    expect(skippedStrings).toContain('XX');
    expect(skippedStrings).toContain('X');
  });

  test('R20-trailing error with single element', () => {
    // Single valid element followed by recovery, then trailing
    const { ok, errorCount } = testParse('S <- "a"+ ;', 'aXaY');
    expect(ok).toBe(true);
    expect(errorCount).toBe(2);
  });
});
