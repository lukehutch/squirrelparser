/**
 * SECTION 11: ALL SIX FIXES WITH MONOTONIC INVARIANT (20 tests)
 * Verify all six error recovery fixes work correctly with the monotonic
 * invariant fix applied.
 */

import { describe, expect, test } from '@jest/globals';
import type { Clause } from '../src';
import { CharRange, First, OneOrMore, Optional, Ref, Seq, Str } from '../src';
import { Parser } from '../src/parser';
import { countDeletions, parse } from './testUtils';

describe('All Fixes with Monotonic Invariant', () => {
  // --- FIX #1: isComplete propagation with LR ---
  const exprLR: Record<string, Clause> = {
    E: new First([
      new Seq([new Ref('E'), new Str('+'), new Ref('N')]),
      new Ref('N'),
    ]),
    N: new OneOrMore(new CharRange('0', '9')),
  };

  test('F1-LR-clean', () => {
    const [ok, err, _] = parse(exprLR, '1+2+3', 'E');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F1-LR-recovery', () => {
    const [ok, err, skip] = parse(exprLR, '1+Z2+3', 'E');
    expect(ok).toBe(true); // should succeed
    expect(err).toBeGreaterThanOrEqual(1); // should have at least 1 error
    expect(skip.some(s => s.includes('Z'))).toBe(true); // should skip Z
  });

  // --- FIX #2: Discovery-only incomplete marking with LR ---
  const repLR: Record<string, Clause> = {
    E: new First([
      new Seq([new Ref('E'), new Str('+'), new Ref('T')]),
      new Ref('T'),
    ]),
    T: new OneOrMore(new Str('x')),
  };

  test('F2-LR-clean', () => {
    const [ok, err, _] = parse(repLR, 'x+xx+xxx', 'E');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F2-LR-error', () => {
    const [ok, err, _skip] = parse(repLR, 'x+xZx+xxx', 'E');
    expect(ok).toBe(true); // should succeed
    expect(err).toBeGreaterThanOrEqual(1); // should have at least 1 error
  });

  // --- FIX #3: Cache isolation with LR ---
  const cacheLR: Record<string, Clause> = {
    S: new Seq([new Str('['), new Ref('E'), new Str(']')]),
    E: new First([
      new Seq([new Ref('E'), new Str('+'), new Ref('N')]),
      new Ref('N'),
    ]),
    N: new OneOrMore(new Str('x')),
  };

  test('F3-LR-clean', () => {
    const [ok, err, _] = parse(cacheLR, '[x+xx]');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F3-LR-recovery', () => {
    const [ok, err, _skip] = parse(cacheLR, '[x+Zxx]');
    expect(ok).toBe(true); // should succeed
    expect(err).toBeGreaterThanOrEqual(1); // should have at least 1 error
  });

  // --- FIX #4: Pre-element bound check with LR ---
  const boundLR: Record<string, Clause> = {
    S: new OneOrMore(new Seq([new Str('['), new Ref('E'), new Str(']')])),
    E: new First([
      new Seq([new Ref('E'), new Str('+'), new Ref('N')]),
      new Ref('N'),
    ]),
    N: new OneOrMore(new CharRange('0', '9')),
  };

  test('F4-LR-clean', () => {
    const [ok, err, _] = parse(boundLR, '[1+2][3+4]');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F4-LR-recovery', () => {
    const [ok, err, _skip] = parse(boundLR, '[1+Z2][3+4]');
    expect(ok).toBe(true); // should succeed
    expect(err).toBeGreaterThanOrEqual(1); // should have at least 1 error
  });

  // --- FIX #5: Optional fallback incomplete with LR ---
  const optLR: Record<string, Clause> = {
    S: new Seq([new Ref('E'), new Optional(new Str(';'))]),
    E: new First([
      new Seq([new Ref('E'), new Str('+'), new Ref('N')]),
      new Ref('N'),
    ]),
    N: new OneOrMore(new CharRange('0', '9')),
  };

  test('F5-LR-with-opt', () => {
    const [ok, err, _] = parse(optLR, '1+2+3;');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F5-LR-without-opt', () => {
    const [ok, err, _] = parse(optLR, '1+2+3');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  // --- FIX #6: Conservative EOF recovery with LR ---
  const eofLR: Record<string, Clause> = {
    S: new Seq([new Ref('E'), new Str('!')]),
    E: new First([
      new Seq([new Ref('E'), new Str('+'), new Ref('N')]),
      new Ref('N'),
    ]),
    N: new OneOrMore(new CharRange('0', '9')),
  };

  test('F6-LR-clean', () => {
    const [ok, err, _] = parse(eofLR, '1+2+3!');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F6-LR-deletion', () => {
    const parser = new Parser(eofLR, '1+2+3');
    const [result, _] = parser.parse('S');
    expect(result !== null && !result.isMismatch).toBe(true); // should succeed with recovery
    expect(countDeletions(result)).toBeGreaterThanOrEqual(1); // should have at least 1 deletion
  });

  // --- Combined: Expression grammar with all features ---
  const fullGrammar: Record<string, Clause> = {
    Program: new OneOrMore(new Seq([new Ref('Expr'), new Optional(new Str(';'))])),
    Expr: new First([
      new Seq([new Ref('Expr'), new Str('+'), new Ref('Term')]),
      new Ref('Term'),
    ]),
    Term: new First([
      new Seq([new Ref('Term'), new Str('*'), new Ref('Factor')]),
      new Ref('Factor'),
    ]),
    Factor: new First([
      new Seq([new Str('('), new Ref('Expr'), new Str(')')]),
      new Ref('Num'),
    ]),
    Num: new OneOrMore(new CharRange('0', '9')),
  };

  test('FULL-clean-simple', () => {
    const [ok, err, _] = parse(fullGrammar, '1+2*3', 'Program');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('FULL-clean-semi', () => {
    const [ok, err, _] = parse(fullGrammar, '1+2;3*4', 'Program');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('FULL-clean-nested', () => {
    const [ok, err, _] = parse(fullGrammar, '(1+2)*(3+4)', 'Program');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('FULL-recovery-skip', () => {
    const [ok, err, _skip] = parse(fullGrammar, '1+Z2*3', 'Program');
    expect(ok).toBe(true); // should succeed
    expect(err).toBeGreaterThanOrEqual(1); // should have at least 1 error
  });

  // --- Deep left recursion ---
  const deepLR: Record<string, Clause> = {
    E: new First([
      new Seq([new Ref('E'), new Str('+'), new Ref('N')]),
      new Ref('N'),
    ]),
    N: new CharRange('0', '9'),
  };

  test('DEEP-LR-clean', () => {
    const [ok, err, _] = parse(deepLR, '1+2+3+4+5+6+7+8+9', 'E');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('DEEP-LR-recovery', () => {
    const [ok, err, _skip] = parse(deepLR, '1+2+Z3+4+5', 'E');
    expect(ok).toBe(true); // should succeed
    expect(err).toBeGreaterThanOrEqual(1); // should have at least 1 error
  });
});
