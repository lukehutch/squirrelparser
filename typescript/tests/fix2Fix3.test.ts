// ===========================================================================
// SECTION 3: FIX #2/#3 - CACHE INTEGRITY (20 tests)
// ===========================================================================

import { testParse } from './testUtils.js';

describe('Fix2/Fix3 - Cache Integrity', () => {
  test('F2-01-Basic probe', () => {
    const result = testParse('S <- "(" "x"+ ")" ;', '(xZZx)');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('ZZ'))).toBe(true);
  });

  test('F2-02-Double probe', () => {
    const result = testParse('S <- "a" "x"+ "b" "y"+ "c" ;', 'axXxbyYyc');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(2);
  });

  test('F2-03-Probe same clause', () => {
    const result = testParse('S <- ("(" "x"+ ")")+ ;', '(xZx)(xYx)');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(2);
    expect(result.skippedStrings.some((s) => s.includes('Z')) && result.skippedStrings.some((s) => s.includes('Y'))).toBe(
      true
    );
  });

  test('F2-04-Triple group', () => {
    const result = testParse('S <- ("[" "x"+ "]")+ ;', '[xAx][xBx][xCx]');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(3);
  });

  test('F2-05-Five groups', () => {
    const result = testParse('S <- ("(" "x"+ ")")+ ;', '(xAx)(xBx)(xCx)(xDx)(xEx)');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(5);
  });

  test('F2-06-Alternating clean/err', () => {
    const result = testParse('S <- ("(" "x"+ ")")+ ;', '(xx)(xZx)(xx)(xYx)(xx)');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(2);
  });

  test('F2-07-Long inner error', () => {
    const result = testParse('S <- "(" "x"+ ")" ;', '(x' + 'Z'.repeat(20) + 'x)');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
  });

  test('F2-08-Nested probe', () => {
    const result = testParse('S <- "{" "(" "x"+ ")" "}" ;', '{(xZx)}');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F2-09-Triple nested', () => {
    const result = testParse('S <- "<" "{" "[" "x"+ "]" "}" ">" ;', '<{[xZx]}>');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F2-10-Ref probe', () => {
    const result = testParse(
      `
      S <- "(" R ")" ;
      R <- "x"+ ;
      `,
      '(xZx)'
    );
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });
});
