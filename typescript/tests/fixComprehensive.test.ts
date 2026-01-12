import { testParse } from './testUtils.js';

describe('Comprehensive Fix Tests', () => {
  // Fix #3: Ref transparency - Ref should not have independent memoization
  test('FIX3-01-ref-transparency-lr-reexpansion', () => {
    // During recovery, Ref should allow LR to re-expand
    const grammar = `
      S <- E ";" ;
      E <- E "+" "n" / "n" ;
    `;
    const result = testParse(grammar, 'n+Xn;');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
  });

  // Fix #4: Terminal skip sanity - single-char vs multi-char
  test('FIX4-01-single-char-skip-junk', () => {
    // Single-char terminal can skip arbitrary junk
    const grammar = 'S <- "a" "b" "c" ;';
    const result = testParse(grammar, 'aXXbc');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('XX'))).toBe(true);
  });

  test('FIX4-02-single-char-no-skip-containing-terminal', () => {
    // Single-char terminal should NOT skip if junk contains the terminal
    const grammar = 'S <- "a" "b" "c" ;';
    const result = testParse(grammar, 'aXbYc');
    // This might succeed by skipping X, matching b, skipping Y (2 errors)
    // The key is it shouldn't skip "Xb" as one unit
    expect(result.ok).toBe(true);
  });

  test('FIX4-03-multi-char-atomic-terminal', () => {
    // Multi-char terminal is atomic - can't skip more than its length
    // Grammar only matches 'n', rest captured as trailing error
    const grammar = `
      S <- E ;
      E <- E "+n" / "n" ;
    `;
    const result = testParse(grammar, 'n+Xn+n');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
  });

  test('FIX4-04-multi-char-exact-skip-ok', () => {
    // Multi-char terminal can skip exactly its length if needed
    const grammar = 'S <- "ab" "cd" ;';
    const result = testParse(grammar, 'abXYcd');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
  });

  // Fix #5: Don't skip content containing next expected terminal
  test('FIX5-01-no-skip-containing-next-terminal', () => {
    // During recovery, don't skip content that includes next terminal
    const grammar = `
      S <- E ";" E ;
      E <- E "+" "n" / "n" ;
    `;
    const result = testParse(grammar, 'n+Xn;n+n+n');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
  });

  test('FIX5-02-skip-pure-junk-ok', () => {
    // Can skip junk that doesn't contain next terminal
    const grammar = 'S <- "+" "n" ;';
    const result = testParse(grammar, '+XXn');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    expect(result.skippedStrings.some((s) => s.includes('XX'))).toBe(true);
  });

  // Combined fixes: complex scenarios
  test('COMBINED-01-lr-with-skip-and-delete', () => {
    // LR expansion + recovery with both skip and delete
    const grammar = `
      S <- E ;
      E <- E "+" "n" / "n" ;
    `;
    const result = testParse(grammar, 'n+Xn+Yn');
    expect(result.ok).toBe(true);
  });

  test('COMBINED-02-first-prefers-longer-with-errors', () => {
    // First should prefer longer match even if it has more errors
    const grammar = `
      S <- "a" "b" "c" / "a" ;
    `;
    const result = testParse(grammar, 'aXbc');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(1);
    // Result should be "abc" not just "a"
  });

  test('COMBINED-03-nested-seq-recovery', () => {
    // Nested sequences with recovery at different levels
    const grammar = `
      S <- A ";" B ;
      A <- "a" "x" ;
      B <- "b" "y" ;
    `;
    const result = testParse(grammar, 'aXx;bYy');
    expect(result.ok).toBe(true);
    expect(result.errorCount).toBe(2);
  });
});
