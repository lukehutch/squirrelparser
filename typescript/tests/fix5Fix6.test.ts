// ===========================================================================
// SECTION 5: FIX #5/#6 - OPTIONAL AND EOF (25 tests)
// ===========================================================================

import { testParse, countDeletions } from './testUtils.js';
import { squirrelParsePT } from '../src/squirrelParse.js';

describe('Fix5/Fix6 - Optional and EOF', () => {
  // Mutual recursion grammar
  const mrGrammar = `
    S <- A ;
    A <- "a" B / "y" ;
    B <- "b" A / "x" ;
  `;

  test('F5-01-aby', () => {
    const result = testParse(mrGrammar, 'aby');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(0);
  });

  test('F5-02-abZy', () => {
    const result = testParse(mrGrammar, 'abZy');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F5-03-ababy', () => {
    const result = testParse(mrGrammar, 'ababy');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(0);
  });

  test('F5-04-ax', () => {
    const result = testParse(mrGrammar, 'ax');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(0);
  });

  test('F5-05-y', () => {
    const result = testParse(mrGrammar, 'y');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(0);
  });

  test('F5-06-abx', () => {
    // 'abx' is NOT in the language: after 'ab' we need A which requires 'a' or 'y', not 'x'
    // Grammar produces: y, ax, aby, abax, ababy, etc.
    // So this requires error recovery (skip 'b' and match 'ax', or skip 'bx' and fail)
    const result = testParse(mrGrammar, 'abx');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBeGreaterThanOrEqual(1);
  });

  test('F5-06b-abax', () => {
    // 'abax' IS in the language: A -> a B -> a b A -> a b a B -> a b a x
    const result = testParse(mrGrammar, 'abax');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(0);
  });

  test('F5-07-ababx', () => {
    // 'ababx' is NOT in the language: after 'abab' we need A which requires 'a' or 'y', not 'x'
    // Grammar produces: y, ax, aby, abax, ababy, ababax, abababy, etc.
    // So this requires error recovery
    const result = testParse(mrGrammar, 'ababx');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBeGreaterThanOrEqual(1);
  });

  test('F5-07b-ababax', () => {
    // 'ababax' IS in the language: A -> a B -> a b A -> a b a B -> a b a b A -> a b a b a B -> a b a b a x
    const result = testParse(mrGrammar, 'ababax');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(0);
  });

  test('F6-01-Optional wrapper', () => {
    const result = testParse('S <- ("x"+ "!")? ;', 'xZx!');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F6-02-Optional at EOF', () => {
    const result = testParse('S <- "x"? ;', '');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(0);
  });

  test('F6-03-Nested optional', () => {
    const result = testParse('S <- (("x"+ "!")?)? ;', 'xZx!');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F6-04-Optional in Seq', () => {
    const result = testParse('S <- ("x"+)? "!" ;', 'xZx!');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('F6-05-EOF del ok', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a" "b" "c" ;',
      topRuleName: 'S',
      input: 'ab',
    });
    const root = parseResult.root;
    expect(root.isMismatch).toBe(false);
    expect(countDeletions([root])).toBe(1);
  });
});
