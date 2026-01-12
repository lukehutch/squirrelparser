// ===========================================================================
// SECTION 8: FIRST (ORDERED CHOICE) (8 tests)
// ===========================================================================

import { testParse } from './testUtils.js';

describe('First (Ordered Choice)', () => {
  test('FR01-match 1st', () => {
    const { ok, errorCount } = testParse(
      'S <- "abc" / "ab" / "a" ;',
      'abc'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('FR02-match 2nd', () => {
    const { ok, errorCount } = testParse(
      'S <- "xyz" / "abc" ;',
      'abc'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('FR03-match 3rd', () => {
    const { ok, errorCount } = testParse(
      'S <- "x" / "y" / "z" ;',
      'z'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('FR04-with recovery', () => {
    const { ok, errorCount, skippedStrings } = testParse(
      'S <- "x"+ "!" / "fallback" ;',
      'xZx!'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('Z');
  });

  test('FR05-fallback', () => {
    const { ok, errorCount } = testParse(
      'S <- "a" "b" / "x" ;',
      'x'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('FR06-none match', () => {
    const { ok } = testParse(
      'S <- "a" / "b" / "c" ;',
      'x'
    );
    expect(ok).toBe(false);
  });

  test('FR07-nested', () => {
    const { ok, errorCount } = testParse(
      'S <- ("a" / "b") / "c" ;',
      'b'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('FR08-deep nested', () => {
    const { ok, errorCount } = testParse(
      'S <- (("a")) ;',
      'a'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });
});
