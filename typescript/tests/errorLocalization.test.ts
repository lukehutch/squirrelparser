// ===========================================================================
// ERROR LOCALIZATION TESTS (Non-Cascading Verification)
// ===========================================================================
// These tests verify that errors don't cascade - each error is localized
// to its specific location without affecting subsequent parsing.

import { testParse } from './testUtils.js';

describe('Error Localization (Non-Cascading) Tests', () => {
  test('CASCADE-01-error-in-first-element-doesnt-affect-second', () => {
    // Error in first element, second element parses cleanly
    const grammar = 'S <- "a" "b" "c" ;';
    const { ok, errorCount, skippedStrings } = testParse(grammar, 'aXbc');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
    // Error localized to position 1, doesn't cascade to 'b' or 'c'
  });

  test('CASCADE-02-error-in-nested-structure', () => {
    // Error inside inner Seq, doesn't affect outer Seq
    const grammar = `
      S <- ("a" "b") "c" ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, 'aXbc');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
    // Error in inner Seq (between 'a' and 'b'), outer Seq continues normally
  });

  test('CASCADE-03-lr-error-doesnt-cascade-to-next-expansion', () => {
    // Error in one LR expansion iteration, next iteration clean
    const grammar = `
      E <- E "+" "n" / "n" ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, 'n+Xn+n', 'E');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
    // Expansion: n (base), n+[skip X]n, n+Xn+n
    // First '+' clean, second '+' has error, third '+' clean
    // Error localized to second iteration
  });

  test('CASCADE-04-multiple-independent-errors', () => {
    // Multiple errors in different parts of parse, all localized
    const grammar = `
      S <- ("a" "b") ("c" "d") ("e" "f") ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, 'aXbcYdeZf');
    expect(ok).toBe(true);
    expect(errorCount).toBe(3);
    expect(skippedStrings).toContain('X');
    expect(skippedStrings).toContain('Y');
    expect(skippedStrings).toContain('Z');
    // Each error localized to its respective Seq
  });

  test('CASCADE-05-error-before-repetition', () => {
    // Error before repetition, repetition parses cleanly
    const grammar = `
      S <- "a" "b"+ ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, 'aXbbb');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
    // Error at position 1, OneOrMore starts cleanly at position 2
  });

  test('CASCADE-06-error-after-repetition', () => {
    // Repetition clean, error after it
    const grammar = `
      S <- "a"+ "b" ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, 'aaaXb');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
    // OneOrMore matches 3 a's cleanly, then error, then 'b'
  });

  test('CASCADE-07-error-in-first-alternative-doesnt-poison-second', () => {
    // First alternative has error, second alternative clean
    const grammar = `
      S <- "a" "b" / "c" ;
    `;
    const { ok, errorCount } = testParse(grammar, 'c');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // First tries and fails, second succeeds cleanly - no cascade
  });

  test('CASCADE-08-recovery-version-increments-correctly', () => {
    // Each recovery increments version, ensuring proper cache invalidation
    const grammar = `
      S <- ("a" "b") ("c" "d") ;
    `;
    const { ok, errorCount } = testParse(grammar, 'aXbcYd');
    expect(ok).toBe(true);
    expect(errorCount).toBe(2);
    // Two recoveries, each increments version, no cache pollution
  });

  test('CASCADE-09-error-at-deeply-nested-level', () => {
    // Error very deep in nesting, doesn't affect outer levels
    const grammar = `
      S <- ((("a" "b") "c") "d") "e" ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, 'aXbcde');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
    // Error localized despite 4 levels of nesting
  });

  test('CASCADE-10-error-recovery-doesnt-leave-parser-in-bad-state', () => {
    // After recovery, parser continues with clean state
    const grammar = `
      S <- ("a" "b") "c" ("d" "e") ;
    `;
    const { ok, errorCount } = testParse(grammar, 'abXcde');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    // After skipping X at position 2, matches 'c' at position 3, then 'de'
  });
});
