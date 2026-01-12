// ===========================================================================
// SECTION 10: UNICODE AND SPECIAL (10 tests)
// ===========================================================================

import { testParse } from './testUtils.js';

describe('Unicode and Special Characters', () => {
  test('U01-Greek', () => {
    const { ok, errorCount, skippedStrings } = testParse('S <- "α"+ ;', 'αβα');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('β');
  });

  test('U02-Chinese', () => {
    const { ok, errorCount, skippedStrings } = testParse('S <- "中"+ ;', '中文中');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('文');
  });

  test('U03-Arabic clean', () => {
    const { ok, errorCount } = testParse('S <- "م"+ ;', 'ممم');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('U04-newline', () => {
    const { ok, errorCount, skippedStrings } = testParse('S <- "x"+ ;', 'x\nx');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('\n');
  });

  test('U05-tab', () => {
    const { ok, errorCount } = testParse('S <- "a" "\\t" "b" ;', 'a\tb');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('U06-space', () => {
    const { ok, errorCount, skippedStrings } = testParse('S <- "x"+ ;', 'x x');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain(' ');
  });

  test('U07-multi space', () => {
    const { ok, errorCount, skippedStrings } = testParse('S <- "x"+ ;', 'x   x');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('   ');
  });

  test('U08-Japanese', () => {
    const { ok, errorCount, skippedStrings } = testParse('S <- "日"+ ;', '日本日');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('本');
  });

  test('U09-Korean', () => {
    const { ok, errorCount, skippedStrings } = testParse('S <- "한"+ ;', '한글한');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('글');
  });

  test('U10-mixed scripts', () => {
    const { ok, errorCount } = testParse('S <- "α" "中" "!" ;', 'α中!');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });
});
