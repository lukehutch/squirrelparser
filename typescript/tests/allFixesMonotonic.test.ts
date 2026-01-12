/**
 * SECTION 11: ALL SIX FIXES WITH MONOTONIC INVARIANT (20 tests)
 *
 * Verify all six error recovery fixes work correctly with the monotonic
 * invariant fix applied.
 */

import { testParse, countDeletions } from './testUtils.js';
import { squirrelParsePT } from '../src/squirrelParse.js';

// --- FIX #1: isComplete propagation with LR ---
const exprLR = `
  E <- E "+" N / N ;
  N <- [0-9]+ ;
`;

describe('Fix 1: isComplete propagation with LR', () => {
  test('F1-LR-clean', () => {
    const r = testParse(exprLR, '1+2+3', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('F1-LR-recovery', () => {
    const r = testParse(exprLR, '1+Z2+3', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBeGreaterThanOrEqual(1);
    expect(r.skippedStrings.some((s) => s.includes('Z'))).toBe(true);
  });
});

// --- FIX #2: Discovery-only incomplete marking with LR ---
const repLR = `
  E <- E "+" T / T ;
  T <- "x"+ ;
`;

describe('Fix 2: Discovery-only incomplete marking with LR', () => {
  test('F2-LR-clean', () => {
    const r = testParse(repLR, 'x+xx+xxx', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('F2-LR-error', () => {
    const r = testParse(repLR, 'x+xZx+xxx', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBeGreaterThanOrEqual(1);
  });
});

// --- FIX #3: Cache isolation with LR ---
const cacheLR = `
  S <- "[" E "]" ;
  E <- E "+" N / N ;
  N <- "x"+ ;
`;

describe('Fix 3: Cache isolation with LR', () => {
  test('F3-LR-clean', () => {
    const r = testParse(cacheLR, '[x+xx]');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('F3-LR-recovery', () => {
    const r = testParse(cacheLR, '[x+Zxx]');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBeGreaterThanOrEqual(1);
  });
});

// --- FIX #4: Pre-element bound check with LR ---
const boundLR = `
  S <- ("[" E "]")+ ;
  E <- E "+" N / N ;
  N <- [0-9]+ ;
`;

describe('Fix 4: Pre-element bound check with LR', () => {
  test('F4-LR-clean', () => {
    const r = testParse(boundLR, '[1+2][3+4]');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('F4-LR-recovery', () => {
    const r = testParse(boundLR, '[1+Z2][3+4]');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBeGreaterThanOrEqual(1);
  });
});

// --- FIX #5: Optional fallback incomplete with LR ---
const optLR = `
  S <- E ";"? ;
  E <- E "+" N / N ;
  N <- [0-9]+ ;
`;

describe('Fix 5: Optional fallback incomplete with LR', () => {
  test('F5-LR-with-opt', () => {
    const r = testParse(optLR, '1+2+3;');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('F5-LR-without-opt', () => {
    const r = testParse(optLR, '1+2+3');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });
});

// --- FIX #6: Conservative EOF recovery with LR ---
const eofLR = `
  S <- E "!" ;
  E <- E "+" N / N ;
  N <- [0-9]+ ;
`;

describe('Fix 6: Conservative EOF recovery with LR', () => {
  test('F6-LR-clean', () => {
    const r = testParse(eofLR, '1+2+3!');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('F6-LR-deletion', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: eofLR,
      topRuleName: 'S',
      input: '1+2+3',
    });
    const result = parseResult.root;
    expect(!result.isMismatch).toBe(true);
    expect(countDeletions([result])).toBeGreaterThanOrEqual(1);
  });
});

// --- Combined: Expression grammar with all features ---
const fullGrammar = `
  Program <- (Expr ";"?)+ ;
  Expr <- Expr "+" Term / Term ;
  Term <- Term "*" Factor / Factor ;
  Factor <- "(" Expr ")" / Num ;
  Num <- [0-9]+ ;
`;

describe('Full grammar with all features', () => {
  test('FULL-clean-simple', () => {
    const r = testParse(fullGrammar, '1+2*3', 'Program');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('FULL-clean-semi', () => {
    const r = testParse(fullGrammar, '1+2;3*4', 'Program');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('FULL-clean-nested', () => {
    const r = testParse(fullGrammar, '(1+2)*(3+4)', 'Program');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('FULL-recovery-skip', () => {
    const r = testParse(fullGrammar, '1+Z2*3', 'Program');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBeGreaterThanOrEqual(1);
  });
});

// --- Deep left recursion ---
const deepLR = `
  E <- E "+" N / N ;
  N <- [0-9] ;
`;

describe('Deep left recursion', () => {
  test('DEEP-LR-clean', () => {
    const r = testParse(deepLR, '1+2+3+4+5+6+7+8+9', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('DEEP-LR-recovery', () => {
    const r = testParse(deepLR, '1+2+Z3+4+5', 'E');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBeGreaterThanOrEqual(1);
  });
});
