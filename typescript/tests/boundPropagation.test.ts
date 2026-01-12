// ===========================================================================
// BOUND PROPAGATION TESTS (FIX #9 Verification)
// ===========================================================================
// These tests verify that bounds propagate through arbitrary nesting levels
// to correctly stop repetitions before consuming delimiters.

import { testParse } from './testUtils.js';

describe('Bound Propagation Tests', () => {
  test('BP-01-direct-repetition', () => {
    // Baseline: Bound with direct Repetition child (was already working)
    const { ok, errorCount } = testParse('S <- "x"+ "end" ;', 'xxxxend');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('BP-02-through-ref', () => {
    // FIX #9: Bound propagates through Ref
    const grammar = `
      S <- A "end" ;
      A <- "x"+ ;
    `;
    const { ok, errorCount } = testParse(grammar, 'xxxxend');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('BP-03-through-nested-refs', () => {
    // FIX #9: Bound propagates through multiple Refs
    const grammar = `
      S <- A "end" ;
      A <- B ;
      B <- "x"+ ;
    `;
    const { ok, errorCount } = testParse(grammar, 'xxxxend');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('BP-04-through-first', () => {
    // FIX #9: Bound propagates through First alternatives
    const grammar = `
      S <- A "end" ;
      A <- "x"+ / "y"+ ;
    `;
    const { ok, errorCount } = testParse(grammar, 'xxxxend');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('BP-05-left-recursive-with-repetition', () => {
    // FIX #9: The EMERG-01 case - bound through LR + First + Seq + Repetition
    const grammar = `
      S <- E "end" ;
      E <- E "+" "n"+ / "n" ;
    `;
    const { ok, errorCount } = testParse(grammar, 'n+nnn+nnend');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('BP-06-with-recovery-inside-bounded-rep', () => {
    // FIX #9 + recovery: Bound propagates AND recovery works inside repetition
    const grammar = `
      S <- A "end" ;
      A <- "ab"+ ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, 'abXabYabend');
    expect(ok).toBe(true);
    expect(errorCount).toBe(2);
    expect(skippedStrings).toContain('X');
    expect(skippedStrings).toContain('Y');
  });

  test('BP-07-multiple-bounds-nested-seq', () => {
    // Multiple bounds in nested Seq structures
    const grammar = `
      S <- A ";" B "end" ;
      A <- "x"+ ;
      B <- "y"+ ;
    `;
    const { ok, errorCount } = testParse(grammar, 'xxxx;yyyyend');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // A stops at ';', B stops at 'end'
  });

  test('BP-08-bound-vs-eof', () => {
    // Without explicit bound, should consume until EOF
    const { ok, errorCount } = testParse('S <- "x"+ ;', 'xxxx');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // No bound, so consumes all x's
  });

  test('BP-09-zeoormore-with-bound', () => {
    // Bound applies to ZeroOrMore too
    const { ok, errorCount } = testParse('S <- "x"* "end" ;', 'end');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('BP-10-complex-nesting', () => {
    // Deeply nested: Ref -> First -> Seq -> Ref -> Repetition
    const grammar = `
      S <- A "end" ;
      A <- "a" B / "fallback" ;
      B <- "x"+ ;
    `;
    const { ok, errorCount } = testParse(grammar, 'axxxxend');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });
});
