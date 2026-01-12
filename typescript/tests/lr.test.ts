// ===========================================================================
// SECTION 9: LEFT RECURSION (10 tests)
// ===========================================================================

import { testParse } from './testUtils.js';

describe('Left Recursion', () => {
  const lr1 = `
    S <- S "+" T / T ;
    T <- [0-9]+ ;
  `;

  const expr = `
    S <- E ;
    E <- E "+" T / T ;
    T <- T "*" F / F ;
    F <- "(" E ")" / [0-9] ;
  `;

  test('LR01-simple', () => {
    const { ok, errorCount } = testParse(lr1, '1+2+3');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('LR02-single', () => {
    const { ok, errorCount } = testParse(lr1, '42');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('LR03-chain 5', () => {
    const { ok, errorCount } = testParse(lr1, Array(5).fill('1').join('+'));
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('LR04-chain 10', () => {
    const { ok, errorCount } = testParse(lr1, Array(10).fill('1').join('+'));
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('LR05-with mult', () => {
    const { ok, errorCount } = testParse(expr, '1+2*3');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('LR06-parens', () => {
    const { ok, errorCount } = testParse(expr, '(1+2)*3');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('LR07-nested parens', () => {
    const { ok, errorCount } = testParse(expr, '((1+2))');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('LR08-direct', () => {
    const { ok, errorCount } = testParse(
      'S <- S "x" / "y" ;',
      'yxxx'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('LR09-multi-digit', () => {
    const { ok, errorCount } = testParse(lr1, '12+345+6789');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('LR10-complex expr', () => {
    const { ok, errorCount } = testParse(expr, '1+2*3+4*5');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });
});
