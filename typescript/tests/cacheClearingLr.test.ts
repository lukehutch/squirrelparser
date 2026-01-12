// =============================================================================
// CACHE CLEARING BUG TESTS (Document 4 fix) and LR RE-EXPANSION TESTS
// =============================================================================

import { testParse } from './testUtils';

// ===========================================================================
// CACHE CLEARING BUG TESTS (Document 4 fix)
// ===========================================================================

describe('Cache Clearing Bug Tests', () => {
  // --- Non-LR incomplete result must be cleared when recovery state changes ---
  // Bug: foundLeftRec && condition prevents clearing non-LR incomplete results

  const staleClearGrammar = `
    S <- A+ "z" ;
    A <- "ab" / "a" ;
  `;

  test('F4-01-stale-nonLR-incomplete', () => {
    // Phase 1: A+ matches 'a' at 0, fails at 'X'. Incomplete, len=1.
    // Phase 2: A+ should skip 'X', match 'ab', get len=4
    // Bug: stale len=1 result returned without clearing
    const r = testParse(staleClearGrammar, 'aXabz');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
    expect(r.skippedStrings.some((s) => s.includes('X'))).toBe(true);
  });

  test('F4-02-stale-nonLR-incomplete-multi', () => {
    // Multiple recovery points in non-LR repetition
    const r = testParse(staleClearGrammar, 'aXaYabz');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(2);
  });

  // --- probe() during Phase 2 must get fresh results ---
  const probeContextGrammar = `
    S <- A B ;
    A <- "a"+ ;
    B <- "a"* "z" ;
  `;

  test('F4-03-probe-context-phase2', () => {
    // Bounded repetition uses probe() to check if B can match
    // probe() must not reuse stale Phase 2 results
    const r = testParse(probeContextGrammar, 'aaaXz');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
  });

  test('F4-04-probe-at-boundary', () => {
    // Edge case: probe at exact boundary between clauses
    const r = testParse(probeContextGrammar, 'aXaz');
    expect(r.ok).toBe(true);
  });
});

// ===========================================================================
// LR RE-EXPANSION TESTS (Complete LR + recovery context change)
// ===========================================================================

describe('LR Re-expansion Tests', () => {
  // --- Direct LR must re-expand in Phase 2 ---
  // NOTE: Using "+" "n" instead of "+n" to allow
  // recovery to skip characters between '+' and 'n'.
  const directLRReexpand = `
    E <- E "+" "n" / "n" ;
  `;

  test('F1-LR-01-reexpand-simple', () => {
    // Phase 1: E matches 'n' (len=1), complete
    // Phase 2: must re-expand to skip 'X' and get 'n+n+n' (len=6)
    const r = testParse(directLRReexpand, 'n+Xn+n', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
    expect(r.skippedStrings.some((s) => s.includes('X'))).toBe(true);
  });

  test('F1-LR-02-reexpand-multiple-errors', () => {
    // Multiple errors in LR expansion
    const r = testParse(directLRReexpand, 'n+Xn+Yn+n', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(2);
  });

  test('F1-LR-03-reexpand-at-start', () => {
    // Error between base 'n' and '+' - recovery should skip X
    const r = testParse(directLRReexpand, 'nX+n+n', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
  });

  // --- Indirect LR re-expansion ---
  const indirectLRReexpand = `
    E <- F / "n" ;
    F <- E "+" "n" ;
  `;

  test('F1-LR-04-indirect-reexpand', () => {
    const r = testParse(indirectLRReexpand, 'n+Xn+n', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
  });

  // --- Multi-level LR (precedence grammar) ---
  const precedenceLRReexpand = `
    E <- E "+" T / T ;
    T <- T "*" F / F ;
    F <- "(" E ")" / "n" ;
  `;

  test('F1-LR-05-multilevel-at-T', () => {
    // Error at T level requires both E and T to re-expand
    const r = testParse(precedenceLRReexpand, 'n+n*Xn', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBeGreaterThanOrEqual(1);
    expect(r.skippedStrings.some((s) => s.includes('X'))).toBe(true);
  });

  test('F1-LR-06-multilevel-at-E', () => {
    // Error at E level
    const r = testParse(precedenceLRReexpand, 'n+Xn*n', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBeGreaterThanOrEqual(1);
  });

  test('F1-LR-07-multilevel-nested-parens', () => {
    // Error inside parentheses
    const r = testParse(precedenceLRReexpand, 'n+(nX*n)', 'E');
    expect(r.ok).toBe(true);
  });

  // --- LR with probe() interaction ---
  const lrProbeGrammar = `
    S <- E+ "z" ;
    E <- E "x" / "a" ;
  `;

  test('F2-LR-01-probe-during-expansion', () => {
    // Repetition probes LR rule E for bounds checking
    const r = testParse(lrProbeGrammar, 'axaXz');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
  });

  test('F2-LR-02-probe-multiple-LR', () => {
    const r = testParse(lrProbeGrammar, 'axaxXz');
    expect(r.ok).toBe(true);
  });
});

// ===========================================================================
// recoveryVersion NECESSITY TESTS
// ===========================================================================

describe('Recovery Version Necessity Tests', () => {
  // --- Distinguish Phase 1 (v=0,e=false) from probe() in Phase 2 (v=1,e=false) ---
  // NOTE: Grammar designed so A* and B don't compete for the same characters.
  // A matches 'a', B matches 'bz'. This way skipping X and matching 'abz' works.
  const recoveryVersionGrammar = `
    S <- A* B ;
    A <- "a" ;
    B <- "b" "z" ;
  `;

  test('F3-RV-01-phase1-vs-probe', () => {
    // Phase 1: A* matches empty at 0 (mismatch on 'X'). B fails.
    // Phase 2: skip X, A* matches 'a', B matches 'bz'.
    const r = testParse(recoveryVersionGrammar, 'Xabz');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
    expect(r.skippedStrings.some((s) => s.includes('X'))).toBe(true);
  });

  test('F3-RV-02-cached-mismatch-reuse', () => {
    // Mismatch cached in Phase 1 should not poison probe() in Phase 2
    const mismatchGrammar = `
      S <- A* B "!" ;
      A <- "a" ;
      B <- "bbb" ;
    `;
    const r = testParse(mismatchGrammar, 'aaXbbb!');
    expect(r.ok).toBe(true);
  });

  test('F3-RV-03-incomplete-different-versions', () => {
    // Incomplete result at (v=0,e=false) vs query at (v=1,e=false)
    const incompleteGrammar = `
      S <- A? B ;
      A <- "aaa" ;
      B <- "a" "z" ;
    `;
    // Phase 1: A? returns incomplete empty (can't match 'X')
    // Phase 2 probe: should recompute, not reuse Phase 1's incomplete
    const r = testParse(incompleteGrammar, 'Xaz');
    expect(r.ok).toBe(true);
  });
});

// ===========================================================================
// DEEP INTERACTION TESTS
// ===========================================================================

describe('Deep Interaction Tests', () => {
  // --- LR + bounded repetition + recovery ---
  const deepInteractionGrammar = `
    S <- E ";" ;
    E <- E "+" T / T ;
    T <- F+ ;
    F <- "n" / "(" E ")" ;
  `;

  test('DEEP-01-LR-bounded-recovery', () => {
    // LR at E level, bounded rep at T level, recovery needed
    const r = testParse(deepInteractionGrammar, 'n+nnXn;');
    expect(r.ok).toBe(true);
  });

  test('DEEP-02-nested-LR-recovery', () => {
    // Recovery inside parenthesized expression under LR
    const r = testParse(deepInteractionGrammar, 'n+(nXn);');
    expect(r.ok).toBe(true);
  });

  test('DEEP-03-multiple-levels', () => {
    // Errors at multiple structural levels
    const r = testParse(deepInteractionGrammar, 'nXn+nYn;');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBeGreaterThanOrEqual(2);
  });
});
