/**
 * SECTION 10: MONOTONIC INVARIANT TESTS (50 tests)
 *
 * These tests verify that the monotonic improvement check only applies to
 * left-recursive clauses, not to all clauses. Without this fix, indirect
 * and interwoven left recursion would fail.
 */

import { testParse, parseForTree } from './testUtils.js';
import { squirrelParsePT } from '../src/squirrelParse.js';

// ===========================================================================
// ADDITIONAL LR PATTERNS (from Pegged wiki examples)
// ===========================================================================
// These test cases cover various left recursion patterns documented at:
// https://github.com/PhilippeSigaud/Pegged/wiki/Left-Recursion

// --- Direct LR: E <- E '+n' / 'n' ---
const directLRSimple = `
  E <- E "+n" / "n" ;
`;

describe('Direct LR', () => {
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
});

// --- Indirect LR: E <- F / 'n'; F <- E '+n' ---
const indirectLRSimple = `
  E <- F / "n" ;
  F <- E "+n" ;
`;

describe('Indirect LR', () => {
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
});

// --- Direct Hidden LR: E <- F? E '+n' / 'n'; F <- 'f' ---
// The optional F? can match empty, making E left-recursive
const directHiddenLR = `
  E <- F? E "+n" / "n" ;
  F <- "f" ;
`;

describe('Direct Hidden LR', () => {
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
});

// --- Indirect Hidden LR: E <- F E '+n' / 'n'; F <- "abc" / 'd'* ---
// F can match empty (via 'd'*), making E left-recursive
const indirectHiddenLR = `
  E <- F E "+n" / "n" ;
  F <- "abc" / "d"* ;
`;

describe('Indirect Hidden LR', () => {
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
});

// --- Multi-step Indirect LR: E <- F '+n' / 'n'; F <- "gh" / J; J <- 'k' / E 'l' ---
// Three-step indirect cycle: E -> F -> J -> E
const multiStepLR = `
  E <- F "+n" / "n" ;
  F <- "gh" / J ;
  J <- "k" / E "l" ;
`;

describe('Multi-step LR', () => {
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
    const r = parseForTree(multiStepLR, 'nl+n', 'E');
    expect(r !== null && r.len === 4).toBe(true);
  });

  test('LR-MultiStep-05-nl+nl+n', () => {
    // Nested multi-step LR
    const r = parseForTree(multiStepLR, 'nl+nl+n', 'E');
    expect(r !== null && r.len === 7).toBe(true);
  });
});

// --- Direct + Indirect LR (Interwoven): L <- P '.x' / 'x'; P <- P '(n)' / L ---
// Two interlocking cycles: L->P->L (indirect) and P->P (direct)
const interwovenLR = `
  L <- P ".x" / "x" ;
  P <- P "(n)" / L ;
`;

describe('Interwoven LR', () => {
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
});

// --- Multiple Interlocking LR Cycles ---
const interlockingLR = `
  E <- F "n" / "n" ;
  F <- E "+" I* / G "-" ;
  G <- H "m" / E ;
  H <- G "l" ;
  I <- "(" A+ ")" ;
  A <- "a" ;
`;

describe('Interlocking LR', () => {
  test('LR-Interlocking-01-n', () => {
    const r = parseForTree(interlockingLR, 'n', 'E');
    expect(r !== null && r.len === 1).toBe(true);
  });

  test('LR-Interlocking-02-n+n', () => {
    const r = parseForTree(interlockingLR, 'n+n', 'E');
    expect(r !== null && r.len === 3).toBe(true);
  });

  test('LR-Interlocking-03-n-n', () => {
    const r = parseForTree(interlockingLR, 'n-n', 'E');
    expect(r !== null && r.len === 3).toBe(true);
  });

  test('LR-Interlocking-04-nlm-n', () => {
    const r = parseForTree(interlockingLR, 'nlm-n', 'E');
    expect(r !== null && r.len === 5).toBe(true);
  });

  test('LR-Interlocking-05-n+(aaa)n', () => {
    const r = parseForTree(interlockingLR, 'n+(aaa)n', 'E');
    expect(r !== null && r.len === 8).toBe(true);
  });

  test('LR-Interlocking-06-nlm-n+(aaa)n', () => {
    const r = parseForTree(interlockingLR, 'nlm-n+(aaa)n', 'E');
    expect(r !== null && r.len === 12).toBe(true);
  });
});

// --- LR Precedence Grammar ---
const precedenceGrammar = `
  E <- E "+" T / E "-" T / T ;
  T <- T "*" F / T "/" F / F ;
  F <- "(" E ")" / "n" ;
`;

describe('LR Precedence', () => {
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
});

// --- LR Error Recovery ---
describe('LR Recovery', () => {
  test('LR-Recovery-leading-error', () => {
    const { ok, errorCount } = testParse(directLRSimple, '+n+n+n+', 'E');
    if (ok) {
      expect(errorCount).toBeGreaterThanOrEqual(1);
    }
  });

  test('LR-Recovery-trailing-plus', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: directLRSimple,
      topRuleName: 'E',
      input: 'n+n+n+',
    });
    const result = parseResult.root;
    if (!result.isMismatch) {
      expect(result.len).toBeGreaterThanOrEqual(5);
    }
  });
});

// --- Indirect Left Recursion (Fig7b): A <- B / 'x'; B <- (A 'y') / (A 'x') ---
const fig7b = `
  A <- B / "x" ;
  B <- A "y" / A "x" ;
`;

describe('Fig7b Indirect LR', () => {
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
});

// --- Interwoven Left Recursion (Fig7f): L <- P '.x' / 'x'; P <- P '(n)' / L ---
const fig7f = `
  L <- P ".x" / "x" ;
  P <- P "(n)" / L ;
`;

describe('Fig7f Interwoven LR', () => {
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
});

// --- Optional-Dependent Left Recursion (Fig7d): A <- 'x'? (A 'y' / A / 'y') ---
const fig7d = `
  A <- "x"? (A "y" / A / "y") ;
`;

describe('Fig7d Optional-Dependent LR', () => {
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
});

// --- Input-Dependent Left Recursion (Fig7c): A <- B / 'z'; B <- ('x' A) / (A 'y') ---
const fig7c = `
  A <- B / "z" ;
  B <- "x" A / A "y" ;
`;

describe('Fig7c Input-Dependent LR', () => {
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
});

// --- Triple-nested indirect LR ---
const tripleLR = `
  A <- B / "a" ;
  B <- C / "b" ;
  C <- A "x" / "c" ;
`;

describe('Triple LR', () => {
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
