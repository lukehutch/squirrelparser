// ===========================================================================
// SECTION 2: FIX #1 - isComplete PROPAGATION (25 tests)
// ===========================================================================

import { testParse } from './testUtils.js';

describe('Fix1 - isComplete Propagation', () => {
  test('F1-01-Rep+Seq basic', () => {
    const result = testParse('S <- "ab"+ "!" ;', 'abXXab!');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('XX'))).toBe(true);
  });

  test('F1-02-Rep+Optional', () => {
    const result = testParse('S <- "ab"+ "!"? ;', 'abXXab');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('XX'))).toBe(true);
  });

  test('F1-03-Rep+Optional+match', () => {
    const result = testParse('S <- "ab"+ "!"? ;', 'abXXab!');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('XX'))).toBe(true);
  });

  test('F1-04-First wrapping', () => {
    const result = testParse('S <- ("ab"+ "!") ;', 'abXXab!');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
  });

  test('F1-05-Nested Seq L1', () => {
    const result = testParse('S <- (("x"+)) ;', 'xZx');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F1-06-Nested Seq L2', () => {
    const result = testParse('S <- ((("x"+))) ;', 'xZx');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F1-07-Nested Seq L3', () => {
    const result = testParse('S <- (((("x"+)))) ;', 'xZx');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F1-08-Optional wrapping', () => {
    const result = testParse('S <- (("x"+))? ;', 'xZx');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F1-09-ZeroOrMore in Seq', () => {
    const result = testParse('S <- "ab"* "!" ;', 'abXXab!');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('XX'))).toBe(true);
  });

  test('F1-10-Multiple Reps', () => {
    const result = testParse('S <- "a"+ "b"+ ;', 'aXabYb');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(2);
  });

  test('F1-11-Rep+Rep+Term', () => {
    const result = testParse('S <- "a"+ "b"+ "!" ;', 'aXabYb!');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(2);
  });

  test('F1-12-Long error span', () => {
    const result = testParse('S <- "x"+ "!" ;', 'x' + 'Z'.repeat(20) + 'x!');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
  });

  test('F1-13-Multiple long errors', () => {
    const result = testParse('S <- "ab"+ ;', 'ab' + 'X'.repeat(10) + 'ab' + 'Y'.repeat(10) + 'ab');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(2);
  });

  test('F1-14-Interspersed errors', () => {
    const result = testParse('S <- "ab"+ ;', 'abXabYabZab');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(3);
  });

  test('F1-15-Five errors', () => {
    const result = testParse('S <- "ab"+ ;', 'abAabBabCabDabEab');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(5);
  });
});
