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

  // ===========================================================================
  // Additional tests for transparent rule skipping and repetition bounds
  // ===========================================================================

  test('BPR-01-repetition-stops-at-sibling-terminal', () => {
    // OneOrMore should stop when sibling terminal can match
    const { ok, errorCount } = testParse('S <- "x"+ "Y" ;', 'xxY');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('BPR-02-repetition-stops-at-sibling-after-error', () => {
    // After recovering from error, repetition should still respect sibling
    const { ok, errorCount, skippedStrings } = testParse('S <- "x"+ "Y" ;', 'xZxY');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('Z');
    expect(skippedStrings).not.toContain('Y');
  });

  test('BPR-03-repetition-stops-at-optional-sibling', () => {
    // Repetition should stop when optional sibling can match
    const { ok, errorCount } = testParse('S <- "x"+ "!"? ;', 'xx!');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('BPR-04-repetition-with-error-stops-at-optional-sibling', () => {
    // After error recovery, repetition should stop at optional sibling
    const { ok, errorCount, skippedStrings } = testParse('S <- "x"+ "!"? ;', 'xZx!');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).not.toContain('!');
  });

  test('WBS-01-bracket-bound-through-whitespace', () => {
    // The "]" should be the effective bound, not WS
    const grammar = `
      S <- "[" WS Items WS "]" ;
      Items <- Item* ;
      Item <- "x" ;
      ~WS <- [ ]* ;
    `;
    const { ok, errorCount } = testParse(grammar, '[xx]');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('WBS-03-bracket-bound-with-error-before-close', () => {
    // Error recovery should stop at "]", not consume it
    const grammar = `
      S <- "[" WS Items WS "]" ;
      Items <- Item* ;
      Item <- "x" ;
      ~WS <- [ ]* ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, '[xZx]');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).not.toContain(']');
  });

  test('ALS-01-simple-array-valid', () => {
    const grammar = `
      S <- "[" (V ("," V)*)? "]" ;
      V <- [0-9]+ ;
    `;
    const { ok, errorCount } = testParse(grammar, '[1,2,3]');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('ALS-03-array-with-error-in-middle', () => {
    // Error between values should be recovered, ] should still match
    const grammar = `
      S <- "[" WS (V (WS "," WS V)*)? WS "]" ;
      V <- [0-9]+ ;
      ~WS <- [ ]* ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, '[1,2X,3]');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
    expect(skippedStrings).not.toContain(']');
  });

  test('ALS-06-nested-arrays', () => {
    // Nested arrays - inner ] should not be consumed by outer repetition
    const grammar = `
      S <- "[" WS (V (WS "," WS V)*)? WS "]" ;
      V <- S / [0-9]+ ;
      ~WS <- [ ]* ;
    `;
    const { ok, errorCount } = testParse(grammar, '[[1,2],3]');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('RDR-01-ref-to-whitespace-skipped', () => {
    // Transparent WS should be skipped, non-transparent RBRACKET should be bound
    const grammar = `
      S <- "[" WS Items WS RBRACKET ;
      Items <- Item* ;
      Item <- "x" ;
      ~WS <- [ ]* ;
      RBRACKET <- "]" ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, '[xZx]');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).not.toContain(']');
  });

  test('RSB-01-no-trailing-skip-past-delimiter', () => {
    // Trailing garbage recovery should stop at delimiter
    const grammar = `
      S <- "[" Items "]" ;
      Items <- "x"+ ;
    `;
    const { ok, skippedStrings } = testParse(grammar, '[xZ]');
    expect(ok).toBe(true);
    expect(skippedStrings).not.toContain(']');
  });

  test('CTR-01-charset-repetition-no-recovery', () => {
    // CharSet repetition should NOT try to skip over non-matching content
    const grammar = `
      S <- [a-z]+ "!" ;
    `;
    const { ok, errorCount } = testParse(grammar, 'abXcd!');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
  });

  test('CTR-03-complex-subclause-does-recovery', () => {
    // Repetition of complex clauses (Seq) SHOULD do recovery
    const grammar = `
      S <- ("ab")+ "!" ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, 'abXab!');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).not.toContain('!');
  });

  // ===========================================================================
  // Additional tests to match Dart test coverage
  // ===========================================================================

  test('BPR-05-nested-repetition-respects-outer-bound', () => {
    const grammar = `
      S <- "[" Items "]" ;
      Items <- Item* ;
      Item <- "x" ;
    `;
    const { ok, errorCount } = testParse(grammar, '[xx]');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('BPR-06-nested-repetition-with-error-respects-bound', () => {
    const grammar = `
      S <- "[" Items "]" ;
      Items <- Item* ;
      Item <- "x" ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, '[xZx]');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).not.toContain(']');
  });

  test('WBS-02-bracket-bound-with-actual-whitespace', () => {
    const grammar = `
      S <- "[" WS Items WS "]" ;
      Items <- (WS Item)* ;
      Item <- "x" ;
      ~WS <- [ ]* ;
    `;
    const { ok, errorCount } = testParse(grammar, '[ x x ]');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('WBS-04-brace-bound-through-whitespace', () => {
    const grammar = `
      S <- "{" WS Items WS "}" ;
      Items <- Item* ;
      Item <- "x" ;
      ~WS <- [ ]* ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, '{xZx}');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).not.toContain('}');
  });

  test('WBS-05-multiple-whitespace-layers', () => {
    const grammar = `
      S <- "[" WS1 WS2 Items WS1 WS2 "]" ;
      Items <- Item* ;
      Item <- "x" ;
      ~WS1 <- [ ]* ;
      ~WS2 <- [\\t]* ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, '[xZx]');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).not.toContain(']');
  });

  test('ALS-02-array-with-whitespace-valid', () => {
    const grammar = `
      S <- "[" WS (V (WS "," WS V)*)? WS "]" ;
      V <- [0-9]+ ;
      ~WS <- [ ]* ;
    `;
    const { ok, errorCount } = testParse(grammar, '[ 1 , 2 , 3 ]');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('RDR-02-multiple-refs-whitespace-all-skipped', () => {
    const grammar = `
      S <- "[" SP TAB Items SP TAB RBRACKET ;
      Items <- Item* ;
      Item <- "x" ;
      ~SP <- [ ]* ;
      ~TAB <- [\\t]* ;
      RBRACKET <- "]" ;
    `;
    const { ok, errorCount, skippedStrings } = testParse(grammar, '[xZx]');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).not.toContain(']');
  });

  test('RSB-02-recovery-scan-stops-at-delimiter', () => {
    const grammar = `
      S <- "[" Items "]" ;
      Items <- ("ab")+ ;
    `;
    const { ok, skippedStrings } = testParse(grammar, '[abZ]');
    expect(ok).toBe(true);
    expect(skippedStrings).not.toContain(']');
  });

  test('RSB-03-multiple-delimiters-nested', () => {
    const grammar = `
      S <- "[" Inner "]" ;
      Inner <- "{" Items "}" ;
      Items <- "x"+ ;
    `;
    const { ok, skippedStrings } = testParse(grammar, '[{xZ}]');
    expect(ok).toBe(true);
    expect(skippedStrings).not.toContain('}');
    expect(skippedStrings).not.toContain(']');
  });
});
