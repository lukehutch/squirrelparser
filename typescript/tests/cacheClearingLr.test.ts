/**
 * CACHE CLEARING BUG TESTS (Document 4 fix) and LR RE-EXPANSION TESTS
 */

import { describe, expect, test } from '@jest/globals';
import type { Clause } from '../src';
import { First, OneOrMore, Optional, Ref, Seq, Str, ZeroOrMore } from '../src';
import { parse } from './testUtils';

describe('Cache Clearing Bug Tests', () => {
  const staleClearGrammar: Record<string, Clause> = {
    S: new Seq([new OneOrMore(new Ref('A')), new Str('z')]),
    A: new First([new Str('ab'), new Str('a')]),
  };

  test('F4-01-stale-nonLR-incomplete', () => {
    // Phase 1: A+ matches 'a' at 0, fails at 'X'. Incomplete, len=1.
    // Phase 2: A+ should skip 'X', match 'ab', get len=4
    // Bug: stale len=1 result returned without clearing
    const [ok, err, skip] = parse(staleClearGrammar, 'aXabz');
    expect(ok).toBe(true); // should recover by skipping X
    expect(err).toBe(1); // should have 1 error
    expect(skip.some(s => s.includes('X'))).toBe(true); // should skip X
  });

  test('F4-02-stale-nonLR-incomplete-multi', () => {
    // Multiple recovery points in non-LR repetition
    const [ok, err, _] = parse(staleClearGrammar, 'aXaYabz');
    expect(ok).toBe(true); // should recover from multiple errors
    expect(err).toBe(2); // should have 2 errors
  });

  // --- probe() during Phase 2 must get fresh results ---
  const probeContextGrammar: Record<string, Clause> = {
    S: new Seq([new Ref('A'), new Ref('B')]),
    A: new OneOrMore(new Str('a')),
    B: new Seq([new ZeroOrMore(new Str('a')), new Str('z')]),
  };

  test('F4-03-probe-context-phase2', () => {
    // Bounded repetition uses probe() to check if B can match
    // probe() must not reuse stale Phase 2 results
    const [ok, err, _] = parse(probeContextGrammar, 'aaaXz');
    expect(ok).toBe(true); // should recover
    expect(err).toBe(1); // should have 1 error
  });

  test('F4-04-probe-at-boundary', () => {
    // Edge case: probe at exact boundary between clauses
    const [ok, _err, _] = parse(probeContextGrammar, 'aXaz');
    expect(ok).toBe(true); // should recover at boundary
  });
});

describe('LR Re-expansion Tests', () => {
  // --- Direct LR must re-expand in Phase 2 ---
  // NOTE: Using Seq([Str('+'), Str('n')]) instead of Str('+n') to allow
  // recovery to skip characters between '+' and 'n'.
  const directLRReexpand: Record<string, Clause> = {
    E: new First([new Seq([new Ref('E'), new Str('+'), new Str('n')]), new Str('n')]),
  };

  test('F1-LR-01-reexpand-simple', () => {
    // Phase 1: E matches 'n' (len=1), complete
    // Phase 2: must re-expand to skip 'X' and get 'n+n+n' (len=6)
    const [ok, err, skip] = parse(directLRReexpand, 'n+Xn+n', 'E');
    expect(ok).toBe(true); // LR must re-expand in Phase 2
    expect(err).toBe(1); // should have 1 error
    expect(skip.some(s => s.includes('X'))).toBe(true); // should skip X
  });

  test('F1-LR-02-reexpand-multiple-errors', () => {
    // Multiple errors in LR expansion
    const [ok, err, _] = parse(directLRReexpand, 'n+Xn+Yn+n', 'E');
    expect(ok).toBe(true); // LR should handle multiple errors
    expect(err).toBe(2); // should have 2 errors
  });

  test('F1-LR-03-reexpand-at-start', () => {
    // Error between base 'n' and '+' - recovery should skip X
    const [ok, err, _] = parse(directLRReexpand, 'nX+n+n', 'E');
    expect(ok).toBe(true); // should recover by skipping X
    expect(err).toBe(1); // should have 1 error
  });

  // --- Indirect LR re-expansion ---
  const indirectLRReexpand: Record<string, Clause> = {
    E: new First([new Ref('F'), new Str('n')]),
    F: new Seq([new Ref('E'), new Str('+'), new Str('n')]),
  };

  test('F1-LR-04-indirect-reexpand', () => {
    const [ok, err, _] = parse(indirectLRReexpand, 'n+Xn+n', 'E');
    expect(ok).toBe(true); // indirect LR must re-expand
    expect(err).toBe(1); // should have 1 error
  });

  // --- Multi-level LR (precedence grammar) ---
  const precedenceLRReexpand: Record<string, Clause> = {
    E: new First([new Seq([new Ref('E'), new Str('+'), new Ref('T')]), new Ref('T')]),
    T: new First([new Seq([new Ref('T'), new Str('*'), new Ref('F')]), new Ref('F')]),
    F: new First([new Seq([new Str('('), new Ref('E'), new Str(')')]), new Str('n')]),
  };

  test('F1-LR-05-multilevel-at-T', () => {
    // Error at T level requires both E and T to re-expand
    const [ok, err, skip] = parse(precedenceLRReexpand, 'n+n*Xn', 'E');
    expect(ok).toBe(true); // multi-level LR must re-expand correctly
    expect(err).toBeGreaterThanOrEqual(1); // should have at least 1 error
    expect(skip.some(s => s.includes('X'))).toBe(true); // should skip X
  });

  test('F1-LR-06-multilevel-at-E', () => {
    // Error at E level
    const [ok, err, _] = parse(precedenceLRReexpand, 'n+Xn*n', 'E');
    expect(ok).toBe(true); // should recover at E level
    expect(err).toBeGreaterThanOrEqual(1); // should have at least 1 error
  });

  test('F1-LR-07-multilevel-nested-parens', () => {
    // Error inside parentheses
    const [ok, _err, _] = parse(precedenceLRReexpand, 'n+(nX*n)', 'E');
    expect(ok).toBe(true); // should recover inside parens
  });

  // --- LR with probe() interaction ---
  const lrProbeGrammar: Record<string, Clause> = {
    S: new Seq([new OneOrMore(new Ref('E')), new Str('z')]),
    E: new First([new Seq([new Ref('E'), new Str('x')]), new Str('a')]),
  };

  test('F2-LR-01-probe-during-expansion', () => {
    // Repetition probes LR rule E for bounds checking
    const [ok, err, _] = parse(lrProbeGrammar, 'axaXz');
    expect(ok).toBe(true); // probe of LR during Phase 2 should work
    expect(err).toBe(1); // should have 1 error
  });

  test('F2-LR-02-probe-multiple-LR', () => {
    const [ok, _err, _] = parse(lrProbeGrammar, 'axaxXz');
    expect(ok).toBe(true); // should handle multiple LR matches before error
  });
});

describe('Recovery Version Necessity Tests', () => {
  // --- Distinguish Phase 1 (v=0,e=false) from probe() in Phase 2 (v=1,e=false) ---
  // NOTE: Grammar designed so A* and B don't compete for the same characters.
  // A matches 'a', B matches 'bz'. This way skipping X and matching 'abz' works.
  const recoveryVersionGrammar: Record<string, Clause> = {
    S: new Seq([new ZeroOrMore(new Ref('A')), new Ref('B')]),
    A: new Str('a'),
    B: new Seq([new Str('b'), new Str('z')]),
  };

  test('F3-RV-01-phase1-vs-probe', () => {
    // Phase 1: A* matches empty at 0 (mismatch on 'X'). B fails.
    // Phase 2: skip X, A* matches 'a', B matches 'bz'.
    const [ok, err, skip] = parse(recoveryVersionGrammar, 'Xabz');
    expect(ok).toBe(true); // should skip X and match abz
    expect(err).toBe(1); // should have 1 error
    expect(skip.some(s => s.includes('X'))).toBe(true); // should skip X
  });

  test('F3-RV-02-cached-mismatch-reuse', () => {
    // Mismatch cached in Phase 1 should not poison probe() in Phase 2
    const mismatchGrammar: Record<string, Clause> = {
      S: new Seq([new ZeroOrMore(new Ref('A')), new Ref('B'), new Str('!')]),
      A: new Str('a'),
      B: new Str('bbb'),
    };
    const [ok, _err, _] = parse(mismatchGrammar, 'aaXbbb!');
    expect(ok).toBe(true); // mismatch from Phase 1 should not block Phase 2 probe
  });

  test('F3-RV-03-incomplete-different-versions', () => {
    // Incomplete result at (v=0,e=false) vs query at (v=1,e=false)
    const incompleteGrammar: Record<string, Clause> = {
      S: new Seq([new Optional(new Ref('A')), new Ref('B')]),
      A: new Str('aaa'),
      B: new Seq([new Str('a'), new Str('z')]),
    };
    // Phase 1: A? returns incomplete empty (can't match 'X')
    // Phase 2 probe: should recompute, not reuse Phase 1's incomplete
    const [ok, _err, _] = parse(incompleteGrammar, 'Xaz');
    expect(ok).toBe(true); // should recover despite incomplete from Phase 1
  });
});

describe('Deep Interaction Tests', () => {
  // --- LR + bounded repetition + recovery ---
  const deepInteractionGrammar: Record<string, Clause> = {
    S: new Seq([new Ref('E'), new Str(';')]),
    E: new First([new Seq([new Ref('E'), new Str('+'), new Ref('T')]), new Ref('T')]),
    T: new OneOrMore(new Ref('F')),
    F: new First([new Str('n'), new Seq([new Str('('), new Ref('E'), new Str(')')])]),
  };

  test('DEEP-01-LR-bounded-recovery', () => {
    // LR at E level, bounded rep at T level, recovery needed
    const [ok, _err, _] = parse(deepInteractionGrammar, 'n+nnXn;');
    expect(ok).toBe(true); // should recover in bounded rep under LR
  });

  test('DEEP-02-nested-LR-recovery', () => {
    // Recovery inside parenthesized expression under LR
    const [ok, _err, _] = parse(deepInteractionGrammar, 'n+(nXn);');
    expect(ok).toBe(true); // should recover inside nested structure
  });

  test('DEEP-03-multiple-levels', () => {
    // Errors at multiple structural levels
    const [ok, err, _] = parse(deepInteractionGrammar, 'nXn+nYn;');
    expect(ok).toBe(true); // should handle errors at multiple levels
    expect(err).toBeGreaterThanOrEqual(2); // should have at least 2 errors
  });
});
