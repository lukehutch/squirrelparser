// ===========================================================================
// LEFT RECURSION + RECOVERY INTERACTION TESTS
// ===========================================================================
// These tests verify that error recovery works correctly during and after
// left-recursive expansion.

import { testParse } from './testUtils';

describe('LR + Recovery Interaction Tests', () => {
  test('LR-INT-01-recovery-during-base-case', () => {
    // Error during LR base case - trailing captured with new invariant
    const grammar = `
      E <- E "+" "n" / "n" ;
    `;
    const r = testParse(grammar, 'nX', 'E');
    // Base case matches 'n', 'X' captured as trailing error
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
    expect(r.skippedStrings.some((s) => s.includes('X'))).toBe(true);
  });

  test('LR-INT-02-recovery-during-growth', () => {
    // Error during LR growth phase
    const grammar = `
      E <- E "+" "n" / "n" ;
    `;
    const r = testParse(grammar, 'n+Xn', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
    expect(r.skippedStrings.some((s) => s.includes('X'))).toBe(true);
    // Base: n, Growth: n + [skip X] n
  });

  test('LR-INT-03-multiple-errors-during-expansion', () => {
    // Multiple errors across multiple expansion iterations
    const grammar = `
      E <- E "+" "n" / "n" ;
    `;
    const r = testParse(grammar, 'n+Xn+Yn+Zn', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(3);
    expect(r.skippedStrings.some((s) => s.includes('X'))).toBe(true);
    expect(r.skippedStrings.some((s) => s.includes('Y'))).toBe(true);
    expect(r.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });

  test('LR-INT-04-nested-lr-with-recovery', () => {
    // E -> E + T | T, T -> T * n | n
    const grammar = `
      E <- E "+" T / T ;
      T <- T "*" "n" / "n" ;
    `;
    const r = testParse(grammar, 'n*Xn+n*Yn', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(2);
    expect(r.skippedStrings.some((s) => s.includes('X'))).toBe(true);
    expect(r.skippedStrings.some((s) => s.includes('Y'))).toBe(true);
  });

  test('LR-INT-05-lr-expansion-stops-on-trailing-error', () => {
    // LR expands as far as possible, trailing captured with new invariant
    const grammar = `
      E <- E "+" "n" / "n" ;
    `;
    const r = testParse(grammar, 'n+n+nX', 'E');
    // Expansion: n, n+n, n+n+n (len=5), then 'X' captured as trailing
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
    expect(r.skippedStrings.some((s) => s.includes('X'))).toBe(true);
  });

  test('LR-INT-06-cache-invalidation-during-recovery', () => {
    // Phase 1: E@0 marked incomplete
    // Phase 2: E@0 must re-expand with recovery
    const grammar = `
      E <- E "+" "n" / "n" ;
    `;
    const r = testParse(grammar, 'n+Xn', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
    expect(r.skippedStrings.some((s) => s.includes('X'))).toBe(true);
    // FIX #6: Cache must be invalidated for LR re-expansion
  });

  test('LR-INT-07-lr-with-repetition-and-recovery', () => {
    // E -> E + n+ | n (nested repetition in LR)
    const grammar = `
      E <- E "+" "n"+ / "n" ;
    `;
    const r = testParse(grammar, 'n+nXnn', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
    expect(r.skippedStrings.some((s) => s.includes('X'))).toBe(true);
  });

  test('LR-INT-08-isFromLRContext-flag', () => {
    // Successful LR results are marked with isFromLRContext
    // But this shouldn't prevent parent recovery (FIX #1)
    const grammar = `
      S <- E "end" ;
      E <- E "+" "n" / "n" ;
    `;
    const r = testParse(grammar, 'n+nend');
    expect(r.ok).toBe(true);
    // E is left-recursive and successful, marked with isFromLRContext
    // But 'end' should still match (FIX #1: only MISMATCH blocks recovery)
  });

  test('LR-INT-09-failed-lr-doesnt-block-recovery', () => {
    // Failed LR (MISMATCH) should NOT be marked isFromLRContext
    // This allows parent to attempt recovery
    const grammar = `
      S <- E "x" ;
      E <- E "+" "n" / "n" ;
    `;
    // Input where E succeeds with recovery, then x matches
    const r = testParse(grammar, 'nXnx');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
    // E matches 'nXn' with recovery, then 'x' matches
  });

  test('LR-INT-10-deep-lr-nesting', () => {
    // Multiple levels of LR with recovery at each level
    const grammar = `
      S <- S "a" T / T ;
      T <- T "b" "x" / "x" ;
    `;
    const r = testParse(grammar, 'xbXxaXxbx', 'S');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(2);
    // Complex nesting: S and T both left-recursive, errors at both levels
  });
});
