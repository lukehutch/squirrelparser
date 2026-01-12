// ===========================================================================
// SECTION 4: FIX #4 - MULTI-LEVEL BOUNDED RECOVERY (35 tests)
// ===========================================================================

import { testParse } from './testUtils.js';

describe('Fix4 - Multi-Level Bounded Recovery', () => {
  test('F4-L1-01-clean 2', () => {
    const result = testParse('S <- ("(" "x"+ ")")+ ;', '(xx)(xx)');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(0);
  });

  test('F4-L1-02-clean 5', () => {
    const result = testParse('S <- ("(" "x"+ ")")+ ;', '(xx)'.repeat(5));
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(0);
  });

  test('F4-L1-03-err first', () => {
    const result = testParse('S <- ("(" "x"+ ")")+ ;', '(xZx)(xx)');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F4-L1-04-err mid', () => {
    const result = testParse('S <- ("(" "x"+ ")")+ ;', '(xx)(xZx)(xx)');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F4-L1-05-err last', () => {
    const result = testParse('S <- ("(" "x"+ ")")+ ;', '(xx)(xZx)');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F4-L1-06-err all 3', () => {
    const result = testParse('S <- ("(" "x"+ ")")+ ;', '(xAx)(xBx)(xCx)');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(3);
    expect(
      result.skippedStrings.some((s) => s.includes('A')) &&
        result.skippedStrings.some((s) => s.includes('B')) &&
        result.skippedStrings.some((s) => s.includes('C'))
    ).toBe(true);
  });

  test('F4-L1-07-boundary', () => {
    const result = testParse('S <- ("(" "x"+ ")")+ ;', '(xx)Z(xx)');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F4-L1-08-long boundary', () => {
    const result = testParse('S <- ("(" "x"+ ")")+ ;', '(xx)ZZZ(xx)');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('ZZZ'))).toBe(true);
  });

  test('F4-L2-01-clean', () => {
    const result = testParse('S <- "{" ("(" "x"+ ")")+ "}" ;', '{(xx)(xx)}');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(0);
  });

  test('F4-L2-02-err inner', () => {
    const result = testParse('S <- "{" ("(" "x"+ ")")+ "}" ;', '{(xx)(xZx)}');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F4-L2-03-err outer', () => {
    const result = testParse('S <- "{" ("(" "x"+ ")")+ "}" ;', '{(xx)Z(xx)}');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F4-L2-04-both levels', () => {
    const result = testParse('S <- "{" ("(" "x"+ ")")+ "}" ;', '{(xAx)B(xCx)}');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(3);
  });

  test('F4-L3-01-clean', () => {
    const result = testParse('S <- "[" "{" ("(" "x"+ ")")+ "}" "]" ;', '[{(xx)(xx)}]');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(0);
  });

  test('F4-L3-02-err deepest', () => {
    const result = testParse('S <- "[" "{" ("(" "x"+ ")")+ "}" "]" ;', '[{(xx)(xZx)}]');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F4-N1-10 groups', () => {
    const result = testParse('S <- ("(" "x"+ ")")+ ;', '(xx)'.repeat(10));
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(0);
  });

  test('F4-N2-10 groups 5 err', () => {
    const input = Array.from({ length: 10 }, (_, i) => (i % 2 === 0 ? '(xZx)' : '(xx)')).join('');
    const result = testParse('S <- ("(" "x"+ ")")+ ;', input);
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(5);
  });

  test('F4-N3-20 groups', () => {
    const result = testParse('S <- ("(" "x"+ ")")+ ;', '(xx)'.repeat(20));
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(0);
  });
});
