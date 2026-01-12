// ===========================================================================
// REPETITION EDGE CASE TESTS
// ===========================================================================
// These tests verify edge cases in repetition handling including nested
// repetitions, probe mechanics, and boundary interactions.

import { testParse } from './testUtils.js';

describe('Repetition Edge Case Tests', () => {
  test('REP-01-zeroormore-empty-match', () => {
    // ZeroOrMore can match zero times
    const { ok, errorCount } = testParse('S <- "x"* "y" ;', 'y');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('REP-02-oneormore-vs-zeroormore-at-eof', () => {
    // OneOrMore requires at least one match, ZeroOrMore doesn't
    const om = testParse('S <- "x"+ ;', '');
    expect(om.ok).toBe(false);

    const zm = testParse('S <- "x"* ;', '');
    expect(zm.ok).toBe(true);
  });

  test('REP-03-nested-repetition', () => {
    // OneOrMore(OneOrMore(x)) - nested repetitions
    const { ok, errorCount } = testParse('S <- ("x"+)+ ;', 'xxxXxxXxxx');
    expect(ok).toBe(true);
    expect(errorCount).toBe(2);
    // Outer: matches 3 times (group1, skip X, group2, skip X, group3)
    // Each group is inner OneOrMore matching x's
  });

  test('REP-04-repetition-with-recovery-hits-bound', () => {
    // Repetition with recovery, encounters bound
    const { ok, errorCount, skippedStrings } = testParse('S <- "x"+ "end" ;', 'xXxXxend');
    expect(ok).toBe(true);
    expect(errorCount).toBe(2);
    expect(skippedStrings).toHaveLength(2);
    // Repetition stops before 'end' (bound)
  });

  test('REP-05-repetition-recovery-vs-probe', () => {
    // ZeroOrMore must probe ahead to avoid consuming boundary
    const { ok, errorCount } = testParse('S <- "x"* "y" ;', 'xxxy');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // ZeroOrMore should match all x's, stop before 'y'
  });

  test('REP-06-alternating-match-skip-pattern', () => {
    // Pattern: match, skip, match, skip, ...
    const { ok, errorCount } = testParse('S <- "ab"+ ;', 'abXabXabXab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(3);
  });

  test('REP-07-repetition-of-complex-structure', () => {
    // OneOrMore(Seq([...])) - repetition of sequences
    const { ok, errorCount } = testParse('S <- ("a" "b")+ ;', 'ababab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // Matches 3 times: (a,b), (a,b), (a,b)
  });

  test('REP-08-repetition-stops-on-non-match', () => {
    // Repetition stops when element no longer matches
    const { ok, errorCount } = testParse('S <- "x"+ "y" ;', 'xxxy');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // OneOrMore matches 3 x's, stops, then 'y' matches
  });

  test('REP-09-repetition-with-first-alternative', () => {
    // OneOrMore(First([...])) - repetition of alternatives
    const { ok, errorCount } = testParse('S <- ("a" / "b")+ ;', 'aabba');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // Matches 5 times: a, a, b, b, a
  });

  test('REP-10-zeroormore-with-recovery-inside', () => {
    // ZeroOrMore element needs recovery
    const { ok, errorCount } = testParse('S <- ("a" "b")* ;', 'abXaYb');
    expect(ok).toBe(true);
    expect(errorCount).toBe(2);
    // First iteration: a, b (clean)
    // Second iteration: Seq needs recovery
    //   Within Seq: 'a' expects 'a' at pos 2, sees 'X', skip X, match 'a' at pos 3
    //   Then 'b' expects 'b' at pos 4, sees 'Y', skip Y, match 'b' at pos 5
    // So yes, 2 errors total
  });

  test('REP-11-greedy-vs-non-greedy', () => {
    // Repetitions are greedy - match as many as possible
    const { ok, errorCount } = testParse('S <- "x"* "y" "z" ;', 'xxxxxyz');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // ZeroOrMore is greedy, matches all x's, then y and z
  });

  test('REP-12-repetition-at-eof-with-deletion', () => {
    // Repetition at EOF can have grammar deletion (completion)
    const { ok } = testParse('S <- "a" "b"+ ;', 'a');
    expect(ok).toBe(true);
    // At EOF, can delete the OneOrMore requirement
  });

  test('REP-13-very-long-repetition', () => {
    // Performance test: many iterations
    const input = 'x'.repeat(1000);
    const { ok, errorCount } = testParse('S <- "x"+ ;', input);
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('REP-14-repetition-with-many-errors', () => {
    // Many errors within repetition
    const input = Array.from({ length: 100 }, () => 'Xx').join('');
    const { ok, errorCount } = testParse('S <- "x"+ ;', input);
    expect(ok).toBe(true);
    expect(errorCount).toBe(100);
  });

  test('REP-15-nested-zeroormore', () => {
    // ZeroOrMore(ZeroOrMore(...)) - both can match zero
    const { ok, errorCount } = testParse('S <- ("x"*)* "y" ;', 'y');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });
});
