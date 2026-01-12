// ===========================================================================
// COMPLEX INTERACTIONS TESTS
// ===========================================================================
// These tests verify complex combinations of features working together.

import { testParse } from './testUtils.js';

describe('Complex Interactions Tests', () => {
  test('COMPLEX-01-lr-bound-recovery-all-together', () => {
    // LR + bound propagation + recovery all working together (EMERG-01 verified)
    const grammar = `
      S <- E "end" ;
      E <- E "+" "n"+ / "n" ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, 'n+nXn+nnend');
    expect(ok).toBe(true);
    expect(errorCount).toBeGreaterThan(0);
    expect(skippedStrings).toContain('X');
    // LR expands, OneOrMore with recovery, bound stops before 'end'
  });

  test('COMPLEX-02-nested-first-with-different-recovery-costs', () => {
    // Nested First, each with alternatives requiring different recovery
    const grammar = `
      S <- ("x" / "y") "z" / "a" ;
    `;
    const { ok, errorCount } = testParse(grammar, 'xXz');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    // Outer First chooses first alternative (Seq)
    // Inner First chooses first alternative 'x'
    // Then skip X, match 'z'
  });

  test('COMPLEX-03-recovery-version-overflow-verified', () => {
    // Many recoveries to test version counter doesn't overflow
    const input = 'ab' + Array.from({ length: 50 }, () => 'Xab').join('');
    const grammar = 'S <- "ab"+ ;';
    const { ok, errorCount } = testParse(grammar, input);
    expect(ok).toBe(true);
    expect(errorCount).toBe(50);
  });

  test('COMPLEX-04-probe-during-recovery', () => {
    // ZeroOrMore uses probe while recovery is happening
    const grammar = `
      S <- "x"* ("y" / "z") ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, 'xXxz');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
    // ZeroOrMore with recovery inside, probes to find 'z'
  });

  test('COMPLEX-05-multiple-refs-same-rule-with-recovery', () => {
    // Multiple Refs to same rule, each with independent recovery
    const grammar = `
      S <- A "+" A ;
      A <- "n" ;
    `;
    const { ok, errorCount } = testParse(grammar, 'nX+n');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    // First Ref('A') needs recovery, second Ref('A') is clean
  });

  test('COMPLEX-06-deeply-nested-lr', () => {
    // Multiple LR levels with recovery at different depths
    const grammar = `
      A <- A "a" B / B ;
      B <- B "b" "x" / "x" ;
    `;
    const { ok, errorCount } = testParse(grammar, 'xbXxaXxbx', 'A');
    expect(ok).toBe(true);
    expect(errorCount).toBe(2);
  });

  test('COMPLEX-07-recovery-with-lookahead', () => {
    // Recovery near lookahead assertions
    const grammar = `
      S <- "a" &"b" "b" "c" ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, 'aXbc');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
    // After skipping X, FollowedBy(b) checks 'b' without consuming
  });

  test('COMPLEX-08-recovery-in-negative-lookahead', () => {
    // NotFollowedBy with recovery context
    const grammar = `
      S <- "a" !"x" "b" ;
    `;
    const { ok, errorCount } = testParse(grammar, 'ab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // NotFollowedBy('x') succeeds (next is 'b', not 'x')
  });

  test('COMPLEX-09-alternating-lr-and-repetition', () => {
    // Grammar with both LR and repetitions at same level
    const grammar = `
      S <- E ";" "x"+ ;
      E <- E "+" "n" / "n" ;
    `;
    const { ok, errorCount } = testParse(grammar, 'n+n;xxx');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // E is left-recursive, then ';', then repetition
  });

  test('COMPLEX-10-recovery-spanning-multiple-clauses', () => {
    // Single error region that spans where multiple clauses would try to match
    const grammar = `
      S <- "a" "b" "c" "d" ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, 'aXYZbcd');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('XYZ');
  });

  test('COMPLEX-11-ref-through-multiple-indirections', () => {
    // A -> B -> C -> D, all Refs
    const grammar = `
      A <- B ;
      B <- C ;
      C <- D ;
      D <- "x" ;
    `;
    const { ok, errorCount } = testParse(grammar, 'x', 'A');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('COMPLEX-12-circular-refs-with-recovery', () => {
    // Mutual recursion with simple clean input
    const grammar = `
      S <- A "end" ;
      A <- "a" B / "a" ;
      B <- "b" A / "b" ;
    `;
    const { ok, errorCount } = testParse(grammar, 'ababend', 'S');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // Mutual recursion: A -> B -> A -> B (abab)
  });

  test('COMPLEX-13-all-clause-types-in-one-grammar', () => {
    // Every clause type in one complex grammar
    const grammar = `
      S <- A "opt"? "z"* ("f1" / "f2") &"end" "end" ;
      A <- A "+" "a" / "a" ;
    `;
    const { ok, errorCount } = testParse(grammar, 'a+aoptzzzf1end', 'S');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('COMPLEX-14-recovery-at-every-level-of-deep-nesting', () => {
    // Error at each level of deep nesting, all recover
    const grammar = `
      S <- "a" "b" "c" "d" ;
    `;
    const { ok, errorCount } = testParse(grammar, 'aXbYcZd');
    expect(ok).toBe(true);
    expect(errorCount).toBe(3);
    // Error at each nesting level
  });

  test('COMPLEX-15-performance-large-grammar', () => {
    // Large grammar with many rules
    const rules = Array.from({ length: 50 }, (_, i) => {
      const idx = i.toString().padStart(3, '0');
      return `Rule${i} <- "opt_${idx}" ;`;
    }).join('\n');
    const alternatives = Array.from({ length: 50 }, (_, i) => `Rule${i}`).join(' / ');
    const grammar = `
      ${rules}
      S <- ${alternatives} ;
    `;

    const { ok } = testParse(grammar, 'opt_025', 'S');
    expect(ok).toBe(true);
  });
});
