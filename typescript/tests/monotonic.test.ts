/**
 * SECTION 10: MONOTONIC INVARIANT TESTS (60 tests)
 *
 * These tests verify that the monotonic improvement check only applies to
 * left-recursive clauses, not to all clauses. Without this fix, indirect
 * and interwoven left recursion would fail.
 */

import { describe, expect, test } from '@jest/globals';
import type { Clause } from '../src';
import { First, OneOrMore, Optional, Parser, Ref, Seq, Str, ZeroOrMore } from '../src';
import { parse, parseForTree } from './testUtils';

describe('Monotonic Invariant Tests', () => {
  // ===========================================================================
  // ADDITIONAL LR PATTERNS (from Pegged wiki examples)
  // ===========================================================================
  // These test cases cover various left recursion patterns documented at:
  // https://github.com/PhilippeSigaud/Pegged/wiki/Left-Recursion

  // --- Direct LR: E <- E '+n' / 'n' ---
  const directLRSimple: Record<string, Clause> = {
    E: new First([
      new Seq([new Ref('E'), new Str('+n')]),
      new Str('n'),
    ]),
  };

  test('LR-Direct-01-n', () => {
    const r = parseForTree(directLRSimple, 'n', 'E');
    expect(r !== null && r.len === 1).toBe(true);
  });

  test('LR-Direct-02-n+n', () => {
    const r = parseForTree(directLRSimple, 'n+n', 'E');
    expect(r !== null && r.len === 3).toBe(true);
  });

  test('LR-Direct-03-n+n+n', () => {
    const r = parseForTree(directLRSimple, 'n+n+n', 'E');
    expect(r !== null && r.len === 5).toBe(true);
  });

  // --- Indirect LR: E <- F / 'n'; F <- E '+n' ---
  const indirectLRSimple: Record<string, Clause> = {
    E: new First([new Ref('F'), new Str('n')]),
    F: new Seq([new Ref('E'), new Str('+n')]),
  };

  test('LR-Indirect-01-n', () => {
    const r = parseForTree(indirectLRSimple, 'n', 'E');
    expect(r !== null && r.len === 1).toBe(true);
  });

  test('LR-Indirect-02-n+n', () => {
    const r = parseForTree(indirectLRSimple, 'n+n', 'E');
    expect(r !== null && r.len === 3).toBe(true);
  });

  test('LR-Indirect-03-n+n+n', () => {
    const r = parseForTree(indirectLRSimple, 'n+n+n', 'E');
    expect(r !== null && r.len === 5).toBe(true);
  });

  // --- Direct Hidden LR: E <- F? E '+n' / 'n'; F <- 'f' ---
  // The optional F? can match empty, making E left-recursive
  const directHiddenLR: Record<string, Clause> = {
    E: new First([
      new Seq([new Optional(new Ref('F')), new Ref('E'), new Str('+n')]),
      new Str('n'),
    ]),
    F: new Str('f'),
  };

  test('LR-DirectHidden-01-n', () => {
    const r = parseForTree(directHiddenLR, 'n', 'E');
    expect(r !== null && r.len === 1).toBe(true);
  });

  test('LR-DirectHidden-02-n+n', () => {
    const r = parseForTree(directHiddenLR, 'n+n', 'E');
    expect(r !== null && r.len === 3).toBe(true);
  });

  test('LR-DirectHidden-03-n+n+n', () => {
    const r = parseForTree(directHiddenLR, 'n+n+n', 'E');
    expect(r !== null && r.len === 5).toBe(true);
  });

  test('LR-DirectHidden-04-fn+n', () => {
    // With the 'f' prefix, right-recursive path
    const r = parseForTree(directHiddenLR, 'fn+n', 'E');
    expect(r !== null && r.len === 4).toBe(true);
  });

  // --- Indirect Hidden LR: E <- F E '+n' / 'n'; F <- "abc" / 'd'* ---
  // F can match empty (via 'd'*), making E left-recursive
  const indirectHiddenLR: Record<string, Clause> = {
    E: new First([
      new Seq([new Ref('F'), new Ref('E'), new Str('+n')]),
      new Str('n'),
    ]),
    F: new First([new Str('abc'), new ZeroOrMore(new Str('d'))]),
  };

  test('LR-IndirectHidden-01-n', () => {
    const r = parseForTree(indirectHiddenLR, 'n', 'E');
    expect(r !== null && r.len === 1).toBe(true);
  });

  test('LR-IndirectHidden-02-n+n', () => {
    const r = parseForTree(indirectHiddenLR, 'n+n', 'E');
    expect(r !== null && r.len === 3).toBe(true);
  });

  test('LR-IndirectHidden-03-n+n+n', () => {
    const r = parseForTree(indirectHiddenLR, 'n+n+n', 'E');
    expect(r !== null && r.len === 5).toBe(true);
  });

  test('LR-IndirectHidden-04-abcn+n', () => {
    // With 'abc' prefix, right-recursive path
    const r = parseForTree(indirectHiddenLR, 'abcn+n', 'E');
    expect(r !== null && r.len === 6).toBe(true);
  });

  test('LR-IndirectHidden-05-ddn+n', () => {
    // With 'dd' prefix, right-recursive path
    const r = parseForTree(indirectHiddenLR, 'ddn+n', 'E');
    expect(r !== null && r.len === 5).toBe(true);
  });

  // --- Multi-step Indirect LR: E <- F '+n' / 'n'; F <- "gh" / J; J <- 'k' / E 'l' ---
  // Three-step indirect cycle: E -> F -> J -> E
  const multiStepLR: Record<string, Clause> = {
    E: new First([
      new Seq([new Ref('F'), new Str('+n')]),
      new Str('n'),
    ]),
    F: new First([new Str('gh'), new Ref('J')]),
    J: new First([
      new Str('k'),
      new Seq([new Ref('E'), new Str('l')]),
    ]),
  };

  test('LR-MultiStep-01-n', () => {
    const r = parseForTree(multiStepLR, 'n', 'E');
    expect(r !== null && r.len === 1).toBe(true);
  });

  test('LR-MultiStep-02-gh+n', () => {
    // F matches "gh"
    const r = parseForTree(multiStepLR, 'gh+n', 'E');
    expect(r !== null && r.len === 4).toBe(true);
  });

  test('LR-MultiStep-03-k+n', () => {
    // F -> J -> 'k'
    const r = parseForTree(multiStepLR, 'k+n', 'E');
    expect(r !== null && r.len === 3).toBe(true);
  });

  test('LR-MultiStep-04-nl+n', () => {
    // E <- F '+n' where F <- J where J <- E 'l'
    // So: E matches 'n', then 'l', giving 'nl' for J, for F
    // Then F '+n' gives 'nl+n'
    const r = parseForTree(multiStepLR, 'nl+n', 'E');
    expect(r !== null && r.len === 4).toBe(true);
  });

  test('LR-MultiStep-05-nl+nl+n', () => {
    // Nested multi-step LR
    const r = parseForTree(multiStepLR, 'nl+nl+n', 'E');
    expect(r !== null && r.len === 7).toBe(true);
  });

  // --- Direct + Indirect LR (Interwoven): L <- P '.x' / 'x'; P <- P '(n)' / L ---
  // Two interlocking cycles: L->P->L (indirect) and P->P (direct)
  const interwovenLR: Record<string, Clause> = {
    L: new First([
      new Seq([new Ref('P'), new Str('.x')]),
      new Str('x'),
    ]),
    P: new First([
      new Seq([new Ref('P'), new Str('(n)')]),
      new Ref('L'),
    ]),
  };

  test('LR-Interwoven-01-x', () => {
    const r = parseForTree(interwovenLR, 'x', 'L');
    expect(r !== null && r.len === 1).toBe(true);
  });

  test('LR-Interwoven-02-x.x', () => {
    const r = parseForTree(interwovenLR, 'x.x', 'L');
    expect(r !== null && r.len === 3).toBe(true);
  });

  test('LR-Interwoven-03-x(n).x', () => {
    const r = parseForTree(interwovenLR, 'x(n).x', 'L');
    expect(r !== null && r.len === 6).toBe(true);
  });

  test('LR-Interwoven-04-x(n)(n).x', () => {
    const r = parseForTree(interwovenLR, 'x(n)(n).x', 'L');
    expect(r !== null && r.len === 9).toBe(true);
  });

  // --- Multiple Interlocking LR Cycles ---
  // E <- F 'n' / 'n'
  // F <- E '+' I* / G '-'
  // G <- H 'm' / E
  // H <- G 'l'
  // I <- '(' A+ ')'
  // A <- 'a'
  // Cycles: E->F->E, F->G->E, G->H->G
  const interlockingLR: Record<string, Clause> = {
    E: new First([
      new Seq([new Ref('F'), new Str('n')]),
      new Str('n'),
    ]),
    F: new First([
      new Seq([new Ref('E'), new Str('+'), new ZeroOrMore(new Ref('I'))]),
      new Seq([new Ref('G'), new Str('-')]),
    ]),
    G: new First([
      new Seq([new Ref('H'), new Str('m')]),
      new Ref('E'),
    ]),
    H: new Seq([new Ref('G'), new Str('l')]),
    I: new Seq([new Str('('), new OneOrMore(new Ref('A')), new Str(')')]),
    A: new Str('a'),
  };

  test('LR-Interlocking-01-n', () => {
    const r = parseForTree(interlockingLR, 'n', 'E');
    expect(r !== null && r.len === 1).toBe(true);
  });

  test('LR-Interlocking-02-n+n', () => {
    // E <- F 'n' where F <- E '+'
    const r = parseForTree(interlockingLR, 'n+n', 'E');
    expect(r !== null && r.len === 3).toBe(true);
  });

  test('LR-Interlocking-03-n-n', () => {
    // E <- F 'n' where F <- G '-' where G <- E
    const r = parseForTree(interlockingLR, 'n-n', 'E');
    expect(r !== null && r.len === 3).toBe(true);
  });

  test('LR-Interlocking-04-nlm-n', () => {
    // G <- H 'm' where H <- G 'l', cycle G->H->G
    const r = parseForTree(interlockingLR, 'nlm-n', 'E');
    expect(r !== null && r.len === 5).toBe(true);
  });

  test('LR-Interlocking-05-n+(aaa)n', () => {
    // E '+' I* where I <- '(' A+ ')'
    const r = parseForTree(interlockingLR, 'n+(aaa)n', 'E');
    expect(r !== null && r.len === 8).toBe(true);
  });

  test('LR-Interlocking-06-nlm-n+(aaa)n', () => {
    // Complex combination of all cycles
    const r = parseForTree(interlockingLR, 'nlm-n+(aaa)n', 'E');
    expect(r !== null && r.len === 12).toBe(true);
  });

  // --- LR Precedence Grammar ---
  // E <- E '+' T / E '-' T / T
  // T <- T '*' F / T '/' F / F
  // F <- '(' E ')' / 'n'
  const precedenceGrammar: Record<string, Clause> = {
    E: new First([
      new Seq([new Ref('E'), new Str('+'), new Ref('T')]),
      new Seq([new Ref('E'), new Str('-'), new Ref('T')]),
      new Ref('T'),
    ]),
    T: new First([
      new Seq([new Ref('T'), new Str('*'), new Ref('F')]),
      new Seq([new Ref('T'), new Str('/'), new Ref('F')]),
      new Ref('F'),
    ]),
    F: new First([
      new Seq([new Str('('), new Ref('E'), new Str(')')]),
      new Str('n'),
    ]),
  };

  test('LR-Precedence-01-n', () => {
    const r = parseForTree(precedenceGrammar, 'n', 'E');
    expect(r !== null && r.len === 1).toBe(true);
  });

  test('LR-Precedence-02-n+n', () => {
    const r = parseForTree(precedenceGrammar, 'n+n', 'E');
    expect(r !== null && r.len === 3).toBe(true);
  });

  test('LR-Precedence-03-n*n', () => {
    const r = parseForTree(precedenceGrammar, 'n*n', 'E');
    expect(r !== null && r.len === 3).toBe(true);
  });

  test('LR-Precedence-04-n+n*n', () => {
    // Precedence: n+(n*n) not (n+n)*n
    const r = parseForTree(precedenceGrammar, 'n+n*n', 'E');
    expect(r !== null && r.len === 5).toBe(true);
  });

  test('LR-Precedence-05-n+n*n+n/n', () => {
    const r = parseForTree(precedenceGrammar, 'n+n*n+n/n', 'E');
    expect(r !== null && r.len === 9).toBe(true);
  });

  test('LR-Precedence-06-(n+n)*n', () => {
    const r = parseForTree(precedenceGrammar, '(n+n)*n', 'E');
    expect(r !== null && r.len === 7).toBe(true);
  });

  // --- LR Error Recovery ---
  test('LR-Recovery-leading-error', () => {
    // Input '+n+n+n+' starts with '+' which is invalid
    const [ok, err, _] = parse(directLRSimple, '+n+n+n+', 'E');
    // Recovery should skip leading '+' and parse rest, or fail
    // The leading '+' can potentially be skipped as garbage
    if (ok) {
      expect(err).toBeGreaterThanOrEqual(1);
    }
  });

  test('LR-Recovery-trailing-plus', () => {
    // Input 'n+n+n+' has trailing '+' with no 'n' after
    const parser = new Parser(directLRSimple, 'n+n+n+');
    const [result, _] = parser.parse('E');
    // Should parse 'n+n+n' and either fail on trailing '+' or recover
    if (result !== null && !result.isMismatch) {
      // If it succeeded, it should have used recovery
      expect(result.len).toBeGreaterThanOrEqual(5);
    }
  });

  // --- Indirect Left Recursion (Fig7b): A <- B / 'x'; B <- (A 'y') / (A 'x') ---
  const fig7b: Record<string, Clause> = {
    A: new First([new Ref('B'), new Str('x')]),
    B: new First([
      new Seq([new Ref('A'), new Str('y')]),
      new Seq([new Ref('A'), new Str('x')]),
    ]),
  };

  test('M-ILR-01-x', () => {
    const r = parseForTree(fig7b, 'x', 'A');
    expect(r !== null && r.len === 1).toBe(true);
  });

  test('M-ILR-02-xx', () => {
    const r = parseForTree(fig7b, 'xx', 'A');
    expect(r !== null && r.len === 2).toBe(true);
  });

  test('M-ILR-03-xy', () => {
    const r = parseForTree(fig7b, 'xy', 'A');
    expect(r !== null && r.len === 2).toBe(true);
  });

  test('M-ILR-04-xxy', () => {
    const r = parseForTree(fig7b, 'xxy', 'A');
    expect(r !== null && r.len === 3).toBe(true);
  });

  test('M-ILR-05-xxyx', () => {
    const r = parseForTree(fig7b, 'xxyx', 'A');
    expect(r !== null && r.len === 4).toBe(true);
  });

  test('M-ILR-06-xyx', () => {
    const r = parseForTree(fig7b, 'xyx', 'A');
    expect(r !== null && r.len === 3).toBe(true);
  });

  // --- Interwoven Left Recursion (Fig7f): L <- P '.x' / 'x'; P <- P '(n)' / L ---
  const fig7f: Record<string, Clause> = {
    L: new First([
      new Seq([new Ref('P'), new Str('.x')]),
      new Str('x'),
    ]),
    P: new First([
      new Seq([new Ref('P'), new Str('(n)')]),
      new Ref('L'),
    ]),
  };

  test('M-IW-01-x', () => {
    const r = parseForTree(fig7f, 'x', 'L');
    expect(r !== null && r.len === 1).toBe(true);
  });

  test('M-IW-02-x.x', () => {
    const r = parseForTree(fig7f, 'x.x', 'L');
    expect(r !== null && r.len === 3).toBe(true);
  });

  test('M-IW-03-x(n).x', () => {
    const r = parseForTree(fig7f, 'x(n).x', 'L');
    expect(r !== null && r.len === 6).toBe(true);
  });

  test('M-IW-04-x(n)(n).x', () => {
    const r = parseForTree(fig7f, 'x(n)(n).x', 'L');
    expect(r !== null && r.len === 9).toBe(true);
  });

  test('M-IW-05-x.x(n)(n).x.x', () => {
    const r = parseForTree(fig7f, 'x.x(n)(n).x.x', 'L');
    expect(r !== null && r.len === 13).toBe(true);
  });

  // --- Optional-Dependent Left Recursion (Fig7d): A <- 'x'? (A 'y' / A / 'y') ---
  const fig7d: Record<string, Clause> = {
    A: new Seq([
      new Optional(new Str('x')),
      new First([
        new Seq([new Ref('A'), new Str('y')]),
        new Ref('A'),
        new Str('y'),
      ]),
    ]),
  };

  test('M-OD-01-y', () => {
    const r = parseForTree(fig7d, 'y', 'A');
    expect(r !== null && r.len === 1).toBe(true);
  });

  test('M-OD-02-xy', () => {
    const r = parseForTree(fig7d, 'xy', 'A');
    expect(r !== null && r.len === 2).toBe(true);
  });

  test('M-OD-03-xxyyy', () => {
    const r = parseForTree(fig7d, 'xxyyy', 'A');
    expect(r !== null && r.len === 5).toBe(true);
  });

  // --- Input-Dependent Left Recursion (Fig7c): A <- B / 'z'; B <- ('x' A) / (A 'y') ---
  const fig7c: Record<string, Clause> = {
    A: new First([new Ref('B'), new Str('z')]),
    B: new First([
      new Seq([new Str('x'), new Ref('A')]),
      new Seq([new Ref('A'), new Str('y')]),
    ]),
  };

  test('M-ID-01-z', () => {
    const r = parseForTree(fig7c, 'z', 'A');
    expect(r !== null && r.len === 1).toBe(true);
  });

  test('M-ID-02-xz', () => {
    const r = parseForTree(fig7c, 'xz', 'A');
    expect(r !== null && r.len === 2).toBe(true);
  });

  test('M-ID-03-zy', () => {
    const r = parseForTree(fig7c, 'zy', 'A');
    expect(r !== null && r.len === 2).toBe(true);
  });

  test('M-ID-04-xxzyyy', () => {
    const r = parseForTree(fig7c, 'xxzyyy', 'A');
    expect(r !== null && r.len === 6).toBe(true);
  });

  // --- Triple-nested indirect LR ---
  const tripleLR: Record<string, Clause> = {
    A: new First([new Ref('B'), new Str('a')]),
    B: new First([new Ref('C'), new Str('b')]),
    C: new First([
      new Seq([new Ref('A'), new Str('x')]),
      new Str('c'),
    ]),
  };

  test('M-TLR-01-a', () => {
    const r = parseForTree(tripleLR, 'a', 'A');
    expect(r !== null && r.len === 1).toBe(true);
  });

  test('M-TLR-02-ax', () => {
    const r = parseForTree(tripleLR, 'ax', 'A');
    expect(r !== null && r.len === 2).toBe(true);
  });

  test('M-TLR-03-axx', () => {
    const r = parseForTree(tripleLR, 'axx', 'A');
    expect(r !== null && r.len === 3).toBe(true);
  });

  test('M-TLR-04-axxx', () => {
    const r = parseForTree(tripleLR, 'axxx', 'A');
    expect(r !== null && r.len === 4).toBe(true);
  });
});
