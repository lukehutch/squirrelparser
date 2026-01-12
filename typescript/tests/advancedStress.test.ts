/**
 * ADVANCED STRESS TESTS FOR SQUIRREL PARSER RECOVERY
 *
 * These tests attempt to expose edge cases, subtle bugs, and potential
 * violations of the three invariants (Completeness, Isolation, Minimality).
 */

import { testParse } from './testUtils.js';

// ===========================================================================
// SECTION A: PHASE ISOLATION ATTACKS
// ===========================================================================

describe('Phase Isolation Attacks', () => {
  test('ISO-01-probe-during-recovery-probe', () => {
    const grammar = `
      S <- A* B ;
      A <- "a"+ "x" ;
      B <- "b" "z" ;
    `;
    const r = testParse(grammar, 'aaXxbz');
    expect(r.ok).toBe(true);
  });

  test('ISO-02-recovery-version-overflow', () => {
    const grammar = 'S <- "ab"+ ;';
    const input = 'ab' + Array.from({ length: 50 }, () => 'Xab').join('');
    const r = testParse(grammar, input);
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(50);
  });

  test('ISO-03-alternating-probe-match', () => {
    const grammar = `
      S <- A* B* "end" ;
      A <- "a" ;
      B <- "a" ;
    `;
    const r = testParse(grammar, 'aaaXend');
    expect(r.ok).toBe(true);
  });

  test('ISO-04-complete-result-reuse-after-lr', () => {
    const grammar = `
      S <- A E ;
      A <- "a" ;
      E <- E "+" "a" / "a" ;
    `;
    const r = testParse(grammar, 'aa+a');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('ISO-05-mismatch-cache-across-phases', () => {
    const grammar = `
      S <- "abc" "xyz" / "ab" "z" ;
    `;
    const r = testParse(grammar, 'abXz');
    expect(r.ok).toBe(true);
  });
});

// ===========================================================================
// SECTION B: LEFT RECURSION EDGE CASES
// ===========================================================================

describe('Left Recursion Edge Cases', () => {
  test('LR-EDGE-01-triple-nested-lr', () => {
    const grammar = `
      A <- A "+" B / B ;
      B <- B "*" C / C ;
      C <- C "-" "n" / "n" ;
    `;
    const r = testParse(grammar, 'n+n*n-Xn', 'A');
    expect(r.ok).toBe(true);
  });

  test('LR-EDGE-02-lr-inside-repetition', () => {
    const grammar = `
      S <- E+ ;
      E <- E "+" "n" / "n" ;
    `;
    const r = testParse(grammar, 'n+nXn+n');
    expect(r.ok).toBe(true);
  });

  test('LR-EDGE-03-lr-with-lookahead', () => {
    const grammar = `
      E <- E "+" T / T ;
      T <- !"+" "n" ;
    `;
    const r = testParse(grammar, 'n+Xn', 'E');
    expect(r.ok).toBe(true);
  });

  test('LR-EDGE-04-mutual-lr', () => {
    const grammar = `
      A <- B "a" / "x" ;
      B <- A "b" / "y" ;
    `;
    const r = testParse(grammar, 'ybaXba', 'A');
    expect(r.ok).toBe(true);
  });

  test('LR-EDGE-05-lr-zero-length-between', () => {
    const grammar = `
      E <- E " "? "+" "n" / "n" ;
    `;
    const r = testParse(grammar, 'n +Xn', 'E');
    expect(r.ok).toBe(true);
  });

  test('LR-EDGE-06-lr-empty-base', () => {
    const grammar = `
      E <- E "+" "n" / "n"? ;
    `;
    // This is a pathological grammar - empty base allows infinite LR
    // Parser should handle gracefully
    testParse(grammar, '+n+n', 'E');
    // May fail or succeed with errors - just shouldn't infinite loop
    expect(true).toBe(true);
  });
});

// ===========================================================================
// SECTION C: RECOVERY MINIMALITY ATTACKS
// ===========================================================================

describe('Recovery Minimality Attacks', () => {
  test('MIN-01-multiple-valid-recoveries', () => {
    const grammar = `
      S <- "a" "b" "c" / "a" "c" ;
    `;
    const r = testParse(grammar, 'aXc');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
  });

  test('MIN-02-grammar-deletion-vs-input-skip', () => {
    const grammar = 'S <- "a" "b" "c" "d" ;';
    const r = testParse(grammar, 'aXd');
    expect(r.ok).toBe(false);

    const r2 = testParse(grammar, 'abc');
    expect(r2.ok).toBe(true);
    expect(r2.errorCount).toBe(1);
  });

  test('MIN-03-greedy-repetition-interaction', () => {
    const grammar = 'S <- "a"+ "b" ;';
    const r = testParse(grammar, 'aaaaXb');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
  });

  test('MIN-04-nested-seq-recovery', () => {
    const grammar = `
      S <- "(" ("a" "b") ")" ;
    `;
    const r = testParse(grammar, '(aXb)');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);

    const r2 = testParse(grammar, '(aX)');
    expect(r2.ok).toBe(false);
  });

  test('MIN-05-recovery-position-optimization', () => {
    const grammar = 'S <- "aaa" "bbb" ;';
    const r = testParse(grammar, 'aaXbbb');
    expect(r.ok).toBe(false);
  });
});

// ===========================================================================
// SECTION D: COMPLETENESS ACCURACY ATTACKS
// ===========================================================================

describe('Completeness Accuracy Attacks', () => {
  test('COMP-01-nested-incomplete', () => {
    const grammar = `
      S <- A "z" ;
      A <- B "y" ;
      B <- C "x" ;
      C <- "a"* ;
    `;
    const r = testParse(grammar, 'aaaQxyz');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
  });

  test('COMP-02-optional-inside-repetition', () => {
    const grammar = `
      S <- ("a" "b"?)+ "z" ;
    `;
    const r = testParse(grammar, 'aabXaz');
    expect(r.ok).toBe(true);
  });

  test('COMP-03-first-alternative-incomplete', () => {
    const grammar = `
      S <- "a"* "x" / "a"* "y" ;
    `;
    const r = testParse(grammar, 'aaaQy');
    expect(r.ok).toBe(true);
  });

  test('COMP-04-complete-zero-length', () => {
    const grammar = 'S <- "x"* "a" ;';
    const r = testParse(grammar, 'a');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('COMP-05-incomplete-at-eof', () => {
    const grammar = 'S <- "a"+ "z" ;';
    const r = testParse(grammar, 'aaa');
    expect(r.ok).toBe(true);
  });
});

// ===========================================================================
// SECTION E: CACHE COHERENCE STRESS TESTS
// ===========================================================================

describe('Cache Coherence Stress Tests', () => {
  test('CACHE-01-same-clause-multiple-positions', () => {
    const grammar = `
      S <- X "+" X ;
      X <- "n" ;
    `;
    const r = testParse(grammar, 'nQn');
    expect(r.ok).toBe(false);

    const r2 = testParse(grammar, 'n+Xn');
    expect(r2.ok).toBe(true);
    expect(r2.errorCount).toBe(1);
  });

  test('CACHE-02-diamond-dependency', () => {
    const grammar = `
      S <- A B ;
      A <- "a" C ;
      B <- "b" C ;
      C <- "c" ;
    `;
    const r = testParse(grammar, 'acXbc');
    expect(r.ok).toBe(true);
  });

  test('CACHE-03-repeated-lr-at-same-pos', () => {
    const grammar = `
      S <- E ";" E ;
      E <- E "+" "n" / "n" ;
    `;
    const r = testParse(grammar, 'n+n;n+Xn');
    expect(r.ok).toBe(true);
  });

  test('CACHE-04-interleaved-lr-and-non-lr', () => {
    const grammar = `
      S <- E "," F "," E ;
      E <- E "+" "n" / "n" ;
      F <- "xyz" ;
    `;
    const r = testParse(grammar, 'n+n,xyz,n+Xn');
    expect(r.ok).toBe(true);
  });

  test('CACHE-05-rapid-phase-switching', () => {
    const grammar = `
      S <- A* B* C* "end" ;
      A <- "a" ;
      B <- "b" ;
      C <- "c" ;
    `;
    const r = testParse(grammar, 'aaaXbbbYcccZend');
    expect(r.ok).toBe(true);
  });
});

// ===========================================================================
// SECTION F: PATHOLOGICAL GRAMMARS
// ===========================================================================

describe('Pathological Grammars', () => {
  function buildDeepFirst(depth: number): string {
    if (depth === 0) return '"target"';
    return `"x" / (${buildDeepFirst(depth - 1)})`;
  }

  test('PATH-01-deeply-nested-first', () => {
    const grammar = `S <- ${buildDeepFirst(20)} ;`;
    const r = testParse(grammar, 'target');
    expect(r.ok).toBe(true);
  });

  function buildDeepSeq(depth: number): string {
    if (depth === 0) return '"x"';
    return `"a" (${buildDeepSeq(depth - 1)})`;
  }

  test('PATH-02-deeply-nested-seq', () => {
    const grammar = `S <- (${buildDeepSeq(20)}) "end" ;`;
    const input = 'a'.repeat(20) + 'Qx' + 'end';
    const r = testParse(grammar, input);
    expect(r.ok).toBe(true);
  });

  test('PATH-03-many-alternatives', () => {
    const alts = Array.from({ length: 50 }, (_, i) => `"opt${i}"`).join(' / ');
    const grammar = `S <- ${alts} / "target" ;`;
    const r = testParse(grammar, 'target');
    expect(r.ok).toBe(true);
  });

  test('PATH-04-wide-seq', () => {
    const elems = Array.from({ length: 30 }, (_, i) => `"${String.fromCharCode(97 + (i % 26))}"`).join(' ');
    const grammar = `S <- ${elems} ;`;
    const input = Array.from({ length: 30 }, (_, i) => String.fromCharCode(97 + (i % 26))).join('');
    const errInput = input.substring(0, 15) + 'X' + input.substring(15);
    const r = testParse(grammar, errInput);
    expect(r.ok).toBe(true);
  });

  test('PATH-05-repetition-of-repetition', () => {
    const grammar = 'S <- ("a"+)+ ;';
    const r = testParse(grammar, 'aaaXaaa');
    expect(r.ok).toBe(true);
  });
});

// ===========================================================================
// SECTION G: REAL-WORLD GRAMMAR PATTERNS
// ===========================================================================

describe('Real-World Grammar Patterns', () => {
  test('REAL-01-json-like-array', () => {
    const grammar = `
      Array <- "[" Elements? "]" ;
      Elements <- Value ("," Value)* ;
      Value <- Array / "n" ;
    `;
    const r = testParse(grammar, '[n n]', 'Array');
    expect(r.ok).toBe(true);
  });

  test('REAL-02-expression-with-parens', () => {
    const grammar = `
      E <- E "+" T / T ;
      T <- T "*" F / F ;
      F <- "(" E ")" / "n" ;
    `;
    const r = testParse(grammar, '(n+n', 'E');
    expect(r.ok).toBe(true);
  });

  test('REAL-03-statement-list', () => {
    const grammar = `
      Program <- Stmt+ ;
      Stmt <- Expr ";" ;
      Expr <- "if" "(" Expr ")" Stmt / "x" ;
    `;
    const r = testParse(grammar, 'x x;', 'Program');
    expect(r.ok).toBe(true);
  });

  test('REAL-04-string-literal', () => {
    const grammar = 'S <- "\\"" [a-z]* "\\"" ;';
    const r = testParse(grammar, '"hello');
    expect(r.ok).toBe(true);
  });

  test('REAL-05-nested-blocks', () => {
    const grammar = `
      Block <- "{" Stmt* "}" ;
      Stmt <- Block / "x" ";" ;
    `;
    const r = testParse(grammar, '{x;{x;Xx;}}', 'Block');
    expect(r.ok).toBe(true);
  });
});

// ===========================================================================
// SECTION H: EMERGENT INTERACTION TESTS
// ===========================================================================

describe('Emergent Interaction Tests', () => {
  test('EMERG-01-lr-with-bounded-rep-recovery', () => {
    const grammar = `
      S <- E "end" ;
      E <- E "+" "n"+ / "n" ;
    `;
    const r = testParse(grammar, 'n+nXn+nnend');
    expect(r.ok).toBe(true);
  });

  test('EMERG-02-probe-triggers-lr', () => {
    const grammar = `
      S <- "a"* E ;
      E <- E "+" "n" / "n" ;
    `;
    const r = testParse(grammar, 'aaXn+n');
    expect(r.ok).toBe(true);
  });

  test('EMERG-03-recovery-resets-lr-expansion', () => {
    const grammar = `
      S <- E ";" E ;
      E <- E "+" "n" / "n" ;
    `;
    const r = testParse(grammar, 'n+Xn;n+n+n');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
  });

  test('EMERG-04-incomplete-propagation-through-lr', () => {
    const grammar = `
      E <- E "+" T / T ;
      T <- "n" "x"* ;
    `;
    const r = testParse(grammar, 'nxx+nxQx', 'E');
    expect(r.ok).toBe(true);
  });

  test('EMERG-05-cache-version-after-lr-recovery', () => {
    const grammar = `
      S <- E ";" E ;
      E <- E "+" "n" / "n" ;
    `;
    const r = testParse(grammar, 'n+Xn+n;n+n');
    expect(r.ok).toBe(true);
  });
});
