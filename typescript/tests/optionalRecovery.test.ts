// ===========================================================================
// OPTIONAL WITH RECOVERY TESTS
// ===========================================================================
// These tests verify Optional behavior with and without recovery.

import { testParse } from './testUtils.js';

describe('Optional Recovery Tests', () => {
  test('OPT-01-optional-matches-cleanly', () => {
    // Optional matches its content cleanly
    const { ok, errorCount } = testParse('S <- "a"? "b" ;', 'ab');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // Optional matches 'a', then 'b'
  });

  test('OPT-02-optional-falls-through-cleanly', () => {
    // Optional doesn't match, falls through
    const { ok, errorCount } = testParse('S <- "a"? "b" ;', 'b');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // Optional returns empty match (len=0), then 'b' matches
  });

  test('OPT-03-optional-with-recovery-attempt', () => {
    // Optional content needs recovery - should Optional try recovery or fall through?
    // Current behavior: Optional tries recovery
    const { ok, errorCount, skippedStrings } = testParse('S <- ("a" "b")? ;', 'aXb');
    expect(ok).toBe(true);
    // If Optional attempts recovery: err=1, skip=['X']
    // If Optional falls through: err=0, but incomplete parse
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
  });

  test('OPT-04-optional-in-sequence', () => {
    // Optional in middle of sequence
    const { ok, errorCount } = testParse('S <- "a" "b"? "c" ;', 'ac');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // 'a' matches, Optional falls through, 'c' matches
  });

  test('OPT-05-nested-optional', () => {
    // Optional(Optional(...))
    const { ok, errorCount } = testParse('S <- "a"?? "b" ;', 'b');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // Both optionals return empty
  });

  test('OPT-06-optional-with-first', () => {
    // Optional(First([...]))
    const { ok, errorCount } = testParse('S <- ("a" / "b")? "c" ;', 'bc');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // Optional matches First's second alternative 'b'
  });

  test('OPT-07-optional-with-repetition', () => {
    // Optional(OneOrMore(...))
    const { ok, errorCount } = testParse('S <- "x"+? "y" ;', 'xxxy');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // Optional matches OneOrMore which matches 3 x's
  });

  test('OPT-08-optional-at-eof', () => {
    // Optional at end of grammar
    const { ok, errorCount } = testParse('S <- "a" "b"? ;', 'a');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // 'a' matches, Optional at EOF returns empty
  });

  test('OPT-09-multiple-optionals', () => {
    // Multiple optionals in sequence
    const { ok, errorCount } = testParse('S <- "a"? "b"? "c" ;', 'c');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
    // Both optionals return empty, 'c' matches
  });

  test('OPT-10-optional-vs-zeroormore', () => {
    // Optional(Str(x)) vs ZeroOrMore(Str(x))
    // Optional: matches 0 or 1 time
    // ZeroOrMore: matches 0 or more times
    const opt = testParse('S <- "x"? "y" ;', 'xxxy');
    // Optional matches first 'x', remaining "xxy" for rest
    // Str('y') sees "xxy", uses recovery to skip "xx", matches 'y'
    expect(opt.ok).toBe(true);
    expect(opt.errorCount).toBe(1);

    const zm = testParse('S <- "x"* "y" ;', 'xxxy');
    expect(zm.ok).toBe(true);
    expect(zm.errorCount).toBe(0);
  });

  test('OPT-11-optional-with-complex-content', () => {
    // Optional(Seq([complex structure]))
    const { ok, errorCount } = testParse(
      'S <- ("if" "(" "x" ")")? "body" ;',
      'if(x)body'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('OPT-12-optional-incomplete-phase1', () => {
    // In Phase 1, if Optional's content is incomplete, should Optional be marked incomplete?
    // This is testing the "mark Optional fallback incomplete" (Modification 5)
    const { ok } = testParse('S <- "a"? "b" ;', 'Xb');
    // Phase 1: Optional tries 'a' at 0, sees 'X', fails
    //   Optional falls through (returns empty), marked incomplete
    // Phase 2: Re-evaluates, Optional might try recovery? Or still fall through?
    expect(ok).toBe(true);
    // If Optional tries recovery in Phase 2, would skip X and fail to find 'a'
    // Then falls through, 'b' matches
  });
});
